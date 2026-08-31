using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Services;

namespace Follow.Api.Tests;

public class MusicImportSourceReaderTests
{
    [Fact]
    public async Task MountedSource_OpensReadOnlyStreamAndReturnsStableSnapshot()
    {
        using var root = new TemporaryDirectory();
        var path = Path.Combine(root.Path, "song.mp3");
        await File.WriteAllBytesAsync(path, [1, 2, 3]);
        var modifiedAt = MusicImportScanner.NormalizeDatabaseTimestamp(File.GetLastWriteTimeUtc(path));
        var expected = new MusicImportSourceSnapshot(
            MusicImportSourceKind.MountedDirectory,
            "song.mp3",
            3,
            modifiedAt,
            null);

        var reader = new MusicImportSourceReader(
            MusicImportScannerTests.EnabledSettings(root.Path),
            new SourceReaderStorage());
        await using var opened = await reader.OpenReadAsync(expected);

        Assert.False(opened.Stream.CanWrite);
        Assert.Equal([1, 2, 3], await ReadAllAsync(opened.Stream));
        Assert.Equal(expected, opened.Snapshot);
    }

    [Fact]
    public async Task MountedSource_RejectsTraversalSymlinksAndChangedSnapshot()
    {
        using var root = new TemporaryDirectory();
        using var outside = new TemporaryDirectory();
        var outsidePath = Path.Combine(outside.Path, "outside.mp3");
        await File.WriteAllBytesAsync(outsidePath, [9]);
        File.CreateSymbolicLink(Path.Combine(root.Path, "linked.mp3"), outsidePath);
        var reader = new MusicImportSourceReader(
            MusicImportScannerTests.EnabledSettings(root.Path),
            new SourceReaderStorage());

        await Assert.ThrowsAsync<ArgumentException>(() => reader.OpenReadAsync(
            new MusicImportSourceSnapshot(
                MusicImportSourceKind.MountedDirectory, "../outside.mp3", 1, DateTime.UtcNow, null)));
        await Assert.ThrowsAsync<InvalidOperationException>(() => reader.OpenReadAsync(
            new MusicImportSourceSnapshot(
                MusicImportSourceKind.MountedDirectory, "linked.mp3", 1, DateTime.UtcNow, null)));

        var path = Path.Combine(root.Path, "changed.mp3");
        await File.WriteAllBytesAsync(path, [1, 2]);
        var actualModified = MusicImportScanner.NormalizeDatabaseTimestamp(File.GetLastWriteTimeUtc(path));
        await Assert.ThrowsAsync<MusicImportSourceChangedException>(() => reader.OpenReadAsync(
            new MusicImportSourceSnapshot(
                MusicImportSourceKind.MountedDirectory,
                "changed.mp3",
                1,
                actualModified,
                null)));
    }

    [Fact]
    public async Task BrowserStaging_UsesObjectKeyAndRejectsChangedEtag()
    {
        var itemId = Guid.NewGuid();
        var objectPath = ImportObjectPath.BuildStaging(itemId, ".flac");
        var storage = new SourceReaderStorage();
        storage.Objects[objectPath] = ([4, 5, 6], "etag-1");
        var reader = new MusicImportSourceReader(
            MusicImportScannerTests.EnabledSettings("/unused-mounted-root"),
            storage);
        var expected = new MusicImportSourceSnapshot(
            MusicImportSourceKind.BrowserStaging,
            objectPath,
            3,
            null,
            "etag-1");

        await using var opened = await reader.OpenReadAsync(expected);
        Assert.Equal([4, 5, 6], await ReadAllAsync(opened.Stream));
        Assert.False(opened.Stream.CanWrite);

        await Assert.ThrowsAsync<MusicImportSourceChangedException>(() => reader.OpenReadAsync(
            expected with { ETag = "stale" }));
    }

    private static async Task<byte[]> ReadAllAsync(Stream stream)
    {
        using var output = new MemoryStream();
        await stream.CopyToAsync(output);
        return output.ToArray();
    }
}

internal sealed class SourceReaderStorage : IStorageService
{
    public Dictionary<string, (byte[] Content, string ETag)> Objects { get; } = [];

    public Task<StorageObjectMetadata?> GetObjectMetadataAsync(
        string filePath,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(Objects.TryGetValue(filePath, out var value)
            ? new StorageObjectMetadata(value.Content.Length, "audio/flac", value.ETag)
            : null);
    }

    public async Task CopyRangeToAsync(
        string filePath,
        long offset,
        long length,
        Stream destination,
        CancellationToken cancellationToken = default)
    {
        var value = Objects[filePath];
        await destination.WriteAsync(
            value.Content.AsMemory((int)offset, (int)length),
            cancellationToken);
    }

    public Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();
    public Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null) =>
        throw new NotSupportedException();
    public Task<bool> DeleteFileAsync(string filePath) => throw new NotSupportedException();
}
