using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

public sealed class MusicImportPreviewService : IMusicImportPreviewService
{
    private readonly FollowDbContext _context;
    private readonly IMusicImportSourceReader _sourceReader;
    private readonly IStorageService _storage;

    public MusicImportPreviewService(
        FollowDbContext context,
        IMusicImportSourceReader sourceReader,
        IStorageService storage)
    {
        _context = context;
        _sourceReader = sourceReader;
        _storage = storage;
    }

    public async Task<IMusicImportPreviewSource?> OpenAsync(
        Guid itemId,
        CancellationToken cancellationToken = default)
    {
        var item = await _context.MusicImportItems
            .AsNoTracking()
            .SingleOrDefaultAsync(candidate => candidate.Id == itemId, cancellationToken);
        if (item == null) return null;

        if (!AudioFilePolicy.TryGetCanonicalContentType(
                item.OriginalFileName,
                out var contentType))
        {
            throw new InvalidDataException("The preview source has an unsupported media type.");
        }

        var reference = item.SourceReference ?? item.RelativePath;
        var snapshot = new MusicImportSourceSnapshot(
            item.SourceKind,
            reference,
            item.SizeBytes,
            item.SourceKind == MusicImportSourceKind.MountedDirectory
                ? item.SourceModifiedAt
                : null,
            item.SourceETag);

        if (item.SourceKind == MusicImportSourceKind.MountedDirectory)
        {
            var handle = await _sourceReader.OpenReadAsync(snapshot, cancellationToken);
            return new MountedPreviewSource(handle, contentType);
        }

        if (item.SourceKind != MusicImportSourceKind.BrowserStaging)
            throw new InvalidDataException("The preview source kind is unsupported.");

        ImportObjectPath.Validate(reference);
        if (!ImportObjectPath.IsStaging(reference))
            throw new InvalidDataException("The browser preview source is invalid.");
        var metadata = await _storage.GetObjectMetadataAsync(reference, cancellationToken);
        if (metadata == null ||
            metadata.Length != snapshot.LengthBytes ||
            !string.Equals(metadata.ETag, snapshot.ETag, StringComparison.Ordinal))
        {
            throw new MusicImportSourceChangedException();
        }

        return new StagingPreviewSource(
            _storage,
            reference,
            metadata.Length,
            contentType,
            metadata.ETag);
    }

    private sealed class MountedPreviewSource(
        MusicImportSourceReadHandle handle,
        string contentType) : IMusicImportPreviewSource
    {
        public long LengthBytes => handle.Snapshot.LengthBytes;
        public string ContentType { get; } = contentType;
        public string? ETag => null;

        public async Task CopyRangeToAsync(
            long offset,
            long length,
            Stream destination,
            CancellationToken cancellationToken = default)
        {
            ValidateRange(offset, length, LengthBytes);
            handle.Stream.Position = offset;
            await CopyExactlyAsync(handle.Stream, destination, length, cancellationToken);
        }

        public ValueTask DisposeAsync() => handle.DisposeAsync();
    }

    private sealed class StagingPreviewSource(
        IStorageService storage,
        string reference,
        long length,
        string contentType,
        string? etag) : IMusicImportPreviewSource
    {
        public long LengthBytes { get; } = length;
        public string ContentType { get; } = contentType;
        public string? ETag { get; } = etag;

        public Task CopyRangeToAsync(
            long offset,
            long requestedLength,
            Stream destination,
            CancellationToken cancellationToken = default)
        {
            ValidateRange(offset, requestedLength, LengthBytes);
            return storage.CopyRangeToAsync(
                reference,
                offset,
                requestedLength,
                destination,
                cancellationToken);
        }

        public ValueTask DisposeAsync() => ValueTask.CompletedTask;
    }

    private static void ValidateRange(long offset, long length, long sourceLength)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(offset);
        ArgumentOutOfRangeException.ThrowIfLessThan(length, 1);
        if (offset > sourceLength - length)
            throw new ArgumentOutOfRangeException(nameof(length));
    }

    private static async Task CopyExactlyAsync(
        Stream source,
        Stream destination,
        long length,
        CancellationToken cancellationToken)
    {
        var buffer = new byte[64 * 1024];
        var remaining = length;
        while (remaining > 0)
        {
            var read = await source.ReadAsync(
                buffer.AsMemory(0, (int)Math.Min(buffer.Length, remaining)),
                cancellationToken);
            if (read == 0)
                throw new MusicImportSourceChangedException();
            await destination.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            remaining -= read;
        }
    }
}
