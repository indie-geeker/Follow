using Follow.Core.Interfaces;
using Follow.Infrastructure.Services;

namespace Follow.Api.Tests;

public sealed class EmbeddedTrackAssetWriterTests
{
    [Fact]
    public async Task WriteAsync_PersistsManagedCoverAndLyrics()
    {
        var storage = new RecordingAssetStorage();
        var writer = new EmbeddedTrackAssetWriter(storage);
        var trackId = Guid.NewGuid();

        var result = await writer.WriteAsync(
            trackId,
            [1, 2, 3],
            "image/jpeg",
            "[00:01.20]line");

        var coverUrl = Assert.IsType<string>(result.CoverUrl);
        var lyricsUrl = Assert.IsType<string>(result.LyricsUrl);
        Assert.Equal($"covers/{trackId}/cover.jpg", coverUrl);
        Assert.Equal($"lyrics/{trackId}/lyrics.lrc", lyricsUrl);
        Assert.Equal([coverUrl, lyricsUrl], result.NewObjectPaths);
        Assert.Equal(
            [
                ($"covers/{trackId}", "cover.jpg", "image/jpeg"),
                ($"lyrics/{trackId}", "lyrics.lrc", "text/plain; charset=utf-8")
            ],
            storage.Uploads.Select(upload =>
                (upload.Folder, upload.FileName, upload.ContentType)));
    }

    [Fact]
    public async Task WriteAsync_RejectsUnsupportedCoverBeforeWritingLyrics()
    {
        var storage = new RecordingAssetStorage();
        var writer = new EmbeddedTrackAssetWriter(storage);

        await Assert.ThrowsAsync<ArgumentException>(() => writer.WriteAsync(
            Guid.NewGuid(),
            [1],
            "image/gif",
            "[00:01.20]line"));

        Assert.Empty(storage.Uploads);
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task WriteAsync_WritesOnlyRequestedAssets(bool cover, bool lyrics)
    {
        var storage = new RecordingAssetStorage();
        var writer = new EmbeddedTrackAssetWriter(storage);

        var result = await writer.WriteAsync(
            Guid.NewGuid(),
            cover ? [1] : null,
            cover ? "image/png" : null,
            lyrics ? "[00:01.20]line" : null);

        Assert.Single(storage.Uploads);
        Assert.Equal(cover, result.CoverUrl != null);
        Assert.Equal(lyrics, result.LyricsUrl != null);
        Assert.Single(result.NewObjectPaths);
    }

    [Fact]
    public async Task WriteAsync_CompensatesCoverWhenLyricsWriteFails()
    {
        var storage = new RecordingAssetStorage { FailUploadNumber = 2 };
        var writer = new EmbeddedTrackAssetWriter(storage);
        var trackId = Guid.NewGuid();

        await Assert.ThrowsAsync<IOException>(() => writer.WriteAsync(
            trackId,
            [1],
            "image/webp",
            "[00:01.20]line"));

        Assert.Equal([$"covers/{trackId}/cover.webp"], storage.Deletes);
    }

    private sealed class RecordingAssetStorage : IStorageService
    {
        public List<(string Folder, string FileName, string ContentType)> Uploads { get; } = [];
        public List<string> Deletes { get; } = [];
        public int? FailUploadNumber { get; init; }

        public Task<string> UploadFileAsync(
            Stream fileStream,
            string fileName,
            string contentType,
            string? folder = null)
        {
            Uploads.Add((folder!, fileName, contentType));
            if (Uploads.Count == FailUploadNumber)
                throw new IOException("simulated upload failure");
            return Task.FromResult($"{folder}/{fileName}");
        }

        public Task<bool> DeleteFileAsync(string filePath)
        {
            Deletes.Add(filePath);
            return Task.FromResult(true);
        }

        public Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) => throw new NotSupportedException();
    }
}
