using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Core.Services;

namespace Follow.Infrastructure.Services;

public sealed class MusicImportSourceReader : IMusicImportSourceReader
{
    private readonly MusicImportRuntimeSettings _settings;
    private readonly IStorageService _storage;

    public MusicImportSourceReader(
        MusicImportRuntimeSettings settings,
        IStorageService storage)
    {
        _settings = settings;
        _storage = storage;
    }

    public Task<MusicImportSourceReadHandle> OpenReadAsync(
        MusicImportSourceSnapshot expectedSnapshot,
        CancellationToken cancellationToken = default) =>
        expectedSnapshot.Kind switch
        {
            MusicImportSourceKind.MountedDirectory =>
                OpenMountedAsync(expectedSnapshot, cancellationToken),
            MusicImportSourceKind.BrowserStaging =>
                OpenStagingAsync(expectedSnapshot, cancellationToken),
            _ => throw new ArgumentOutOfRangeException(nameof(expectedSnapshot))
        };

    private Task<MusicImportSourceReadHandle> OpenMountedAsync(
        MusicImportSourceSnapshot expected,
        CancellationToken cancellationToken)
    {
        ValidateExpected(expected);
        cancellationToken.ThrowIfCancellationRequested();
        var resolved = MusicImportPathPolicy.Resolve(
            _settings.SourceRoot,
            expected.Reference,
            _settings.MaximumRelativePathLength);
        EnsureNoReparsePoints(_settings.SourceRoot, resolved.RelativePath);

        var file = new FileInfo(resolved.FullPath);
        if (!file.Exists)
            throw new MusicImportSourceChangedException();
        if (MusicImportPathPolicy.IsReparsePoint(file))
            throw new InvalidOperationException("Import source links are not allowed.");

        var actual = new MusicImportSourceSnapshot(
            MusicImportSourceKind.MountedDirectory,
            resolved.RelativePath,
            file.Length,
            MusicImportScanner.NormalizeDatabaseTimestamp(file.LastWriteTimeUtc),
            null);
        EnsureSnapshotMatches(expected, actual);

        var stream = new FileStream(
            resolved.FullPath,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            64 * 1024,
            FileOptions.Asynchronous | FileOptions.SequentialScan);
        if (stream.Length != actual.LengthBytes)
        {
            stream.Dispose();
            throw new MusicImportSourceChangedException();
        }
        return Task.FromResult(new MusicImportSourceReadHandle(stream, actual));
    }

    private async Task<MusicImportSourceReadHandle> OpenStagingAsync(
        MusicImportSourceSnapshot expected,
        CancellationToken cancellationToken)
    {
        ValidateExpected(expected);
        ImportObjectPath.Validate(expected.Reference);
        if (!ImportObjectPath.IsStaging(expected.Reference))
            throw new ArgumentException("Browser sources must use a staging object key.", nameof(expected));

        var metadata = await _storage.GetObjectMetadataAsync(expected.Reference, cancellationToken)
            ?? throw new MusicImportSourceChangedException();
        var actual = new MusicImportSourceSnapshot(
            MusicImportSourceKind.BrowserStaging,
            expected.Reference,
            metadata.Length,
            null,
            metadata.ETag);
        EnsureSnapshotMatches(expected, actual);

        var temporaryPath = Path.Combine(
            Path.GetTempPath(),
            $"follow-import-source-{Guid.NewGuid():N}.tmp");
        try
        {
            await using (var destination = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                64 * 1024,
                FileOptions.Asynchronous | FileOptions.SequentialScan))
            {
                if (!OperatingSystem.IsWindows())
                {
                    File.SetUnixFileMode(
                        temporaryPath,
                        UnixFileMode.UserRead | UnixFileMode.UserWrite);
                }
                await _storage.CopyRangeToAsync(
                    expected.Reference,
                    0,
                    metadata.Length,
                    destination,
                    cancellationToken);
                await destination.FlushAsync(cancellationToken);
            }

            var stream = new FileStream(
                temporaryPath,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read,
                64 * 1024,
                FileOptions.Asynchronous | FileOptions.SequentialScan);
            if (stream.Length != metadata.Length)
            {
                await stream.DisposeAsync();
                throw new MusicImportSourceChangedException();
            }
            return new MusicImportSourceReadHandle(stream, actual, temporaryPath);
        }
        catch
        {
            if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
            throw;
        }
    }

    private void ValidateExpected(MusicImportSourceSnapshot expected)
    {
        ArgumentNullException.ThrowIfNull(expected);
        if (expected.LengthBytes <= 0 || expected.LengthBytes > _settings.MaximumFileBytes)
            throw new ArgumentOutOfRangeException(nameof(expected));
    }

    private static void EnsureSnapshotMatches(
        MusicImportSourceSnapshot expected,
        MusicImportSourceSnapshot actual)
    {
        if (expected.Kind != actual.Kind ||
            !string.Equals(expected.Reference, actual.Reference, StringComparison.Ordinal) ||
            expected.LengthBytes != actual.LengthBytes ||
            expected.LastModifiedAt != actual.LastModifiedAt ||
            !string.Equals(expected.ETag, actual.ETag, StringComparison.Ordinal))
        {
            throw new MusicImportSourceChangedException();
        }
    }

    private static void EnsureNoReparsePoints(string root, string relativePath)
    {
        var current = new DirectoryInfo(Path.GetFullPath(root));
        if (!current.Exists || MusicImportPathPolicy.IsReparsePoint(current))
            throw new InvalidOperationException("The mounted import root is unavailable or linked.");

        var segments = relativePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
        for (var index = 0; index < segments.Length - 1; index++)
        {
            current = new DirectoryInfo(Path.Combine(current.FullName, segments[index]));
            if (!current.Exists || MusicImportPathPolicy.IsReparsePoint(current))
                throw new InvalidOperationException("Import source directory links are not allowed.");
        }
    }
}
