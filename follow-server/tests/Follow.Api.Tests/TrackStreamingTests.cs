using Follow.Api.Media;
using Follow.Core.Interfaces;
using Microsoft.AspNetCore.Http;

namespace Follow.Api.Tests;

public class TrackStreamingTests
{
    [Fact]
    public async Task StorageObjectResult_CopiesOnlyRequestedRange()
    {
        var source = Enumerable.Range(0, 1000).Select(value => (byte)(value % 251)).ToArray();
        var storage = new RecordingStorageService(source, "audio/mpeg");
        var context = new DefaultHttpContext();
        context.Request.Headers.Range = "bytes=100-199";
        context.Response.Body = new MemoryStream();
        var result = new StorageObjectResult(storage, "tracks/id/song.mp3", "audio/mpeg");

        await result.ExecuteAsync(context);

        Assert.Equal(StatusCodes.Status206PartialContent, context.Response.StatusCode);
        Assert.Equal("bytes 100-199/1000", context.Response.Headers.ContentRange);
        Assert.Equal(100L, context.Response.Headers.ContentLength);
        Assert.Equal((100L, 100L), storage.LastRange);
        Assert.Equal(source[100..200], ((MemoryStream)context.Response.Body).ToArray());
    }

    [Fact]
    public async Task StorageObjectResult_Returns416WithoutReadingObject()
    {
        var storage = new RecordingStorageService(new byte[10], "audio/mpeg");
        var context = new DefaultHttpContext();
        context.Request.Headers.Range = "bytes=10-";
        context.Response.Body = new MemoryStream();
        var result = new StorageObjectResult(storage, "tracks/id/song.mp3", "audio/mpeg");

        await result.ExecuteAsync(context);

        Assert.Equal(StatusCodes.Status416RangeNotSatisfiable, context.Response.StatusCode);
        Assert.Equal("bytes */10", context.Response.Headers.ContentRange);
        Assert.Null(storage.LastRange);
    }

    [Fact]
    public async Task StorageObjectResult_HeadReturnsHeadersWithoutReadingObject()
    {
        var storage = new RecordingStorageService(new byte[10], "audio/mpeg");
        var context = new DefaultHttpContext();
        context.Request.Method = HttpMethods.Head;
        context.Response.Body = new MemoryStream();
        var result = new StorageObjectResult(storage, "tracks/id/song.mp3", "audio/mpeg");

        await result.ExecuteAsync(context);

        Assert.Equal(StatusCodes.Status200OK, context.Response.StatusCode);
        Assert.Equal(10L, context.Response.ContentLength);
        Assert.Null(storage.LastRange);
        Assert.Empty(((MemoryStream)context.Response.Body).ToArray());
    }

    [Fact]
    public async Task StorageObjectResult_DoesNotTrustStoredContentType()
    {
        var storage = new RecordingStorageService(new byte[10], "text/html");
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();
        var result = new StorageObjectResult(
            storage,
            "covers/id/cover.jpg",
            "image/jpeg");

        await result.ExecuteAsync(context);

        Assert.Equal("image/jpeg", context.Response.ContentType);
    }

    [Fact]
    public async Task StorageObjectResult_ForwardsRequestCancellation()
    {
        var storage = new RecordingStorageService(new byte[10], "audio/mpeg");
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var context = new DefaultHttpContext();
        context.RequestAborted = cancellation.Token;
        context.Response.Body = new MemoryStream();
        var result = new StorageObjectResult(storage, "tracks/id/song.mp3", "audio/mpeg");

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => result.ExecuteAsync(context));

        Assert.True(storage.CopyObservedCancellation);
    }

    [Theory]
    [InlineData("covers/id/file.jpg", true)]
    [InlineData("covers/id/a+b.jpg", true)]
    [InlineData("artists/id/cover/file.webp", true)]
    [InlineData("albums/id/cover/file.png", true)]
    [InlineData("tracks/id/song.mp3", false)]
    [InlineData("lyrics/id/song.lrc", false)]
    [InlineData("covers/id/file.exe", false)]
    [InlineData("covers/../tracks/id/song.mp3", false)]
    public void AnonymousCoverPolicy_RestrictsPrefixesAndImageExtensions(
        string path,
        bool expected)
    {
        Assert.Equal(expected, MediaPathPolicy.AllowsAnonymousCover(path));
    }

    [Fact]
    public void CoverEndpoint_DoesNotDecodeCatchAllPathAgain()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Api/Endpoints/TrackEndpoints.cs"));

        Assert.DoesNotContain("UrlDecode(path)", source);
    }

    private sealed class RecordingStorageService : IStorageService
    {
        private readonly byte[] _content;
        private readonly string _contentType;

        public RecordingStorageService(byte[] content, string contentType)
        {
            _content = content;
            _contentType = contentType;
        }

        public (long Offset, long Length)? LastRange { get; private set; }
        public bool CopyObservedCancellation { get; private set; }

        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(
            string filePath,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<StorageObjectMetadata?>(new(
                _content.LongLength,
                _contentType,
                "etag"));

        public async Task CopyRangeToAsync(
            string filePath,
            long offset,
            long length,
            Stream destination,
            CancellationToken cancellationToken = default)
        {
            LastRange = (offset, length);
            CopyObservedCancellation = cancellationToken.IsCancellationRequested;
            cancellationToken.ThrowIfCancellationRequested();
            await destination.WriteAsync(
                _content.AsMemory((int)offset, (int)length),
                cancellationToken);
        }

        public Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default) => throw new NotSupportedException();

        public Task<string> UploadFileAsync(
            Stream fileStream,
            string fileName,
            string contentType,
            string? folder = null) => throw new NotSupportedException();

        public Task<bool> DeleteFileAsync(string filePath) => throw new NotSupportedException();

    }
}
