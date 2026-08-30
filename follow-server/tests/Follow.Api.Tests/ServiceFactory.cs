using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.Extensions.Logging.Abstractions;

namespace Follow.Api.Tests;

internal static class ServiceFactory
{
    public static TrackService CreateTrackService(FollowDbContext context)
    {
        var storage = new NoopStorageService();
        var queue = new StorageDeletionQueue(context);
        var artistService = new ArtistService(
            context, storage, queue, NullLogger<ArtistService>.Instance);
        var albumService = new AlbumService(
            context, storage, queue, NullLogger<AlbumService>.Instance);
        return new TrackService(
            context,
            storage,
            artistService,
            albumService,
            queue,
            NullLogger<TrackService>.Instance);
    }

    private sealed class NoopStorageService : IStorageService
    {
        public Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null) => throw new NotSupportedException();
        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<bool> DeleteFileAsync(string filePath) => throw new NotSupportedException();
    }
}
