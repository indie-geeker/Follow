using Follow.Api.Media;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public class MusicImportPreviewTests
{
    [Theory]
    [InlineData(null, 200, null, 0, 10)]
    [InlineData("bytes=2-5", 206, "bytes 2-5/10", 2, 4)]
    [InlineData("bytes=4-", 206, "bytes 4-9/10", 4, 6)]
    [InlineData("bytes=-3", 206, "bytes 7-9/10", 7, 3)]
    public async Task SourceStreamResult_StreamsOnlyRequestedBytes(
        string? range,
        int expectedStatus,
        string? expectedContentRange,
        long expectedOffset,
        long expectedLength)
    {
        var source = new RecordingPreviewSource(Enumerable.Range(0, 10)
            .Select(value => (byte)value)
            .ToArray());
        var context = Context(HttpMethods.Get, range);

        await new SourceStreamResult(source).ExecuteAsync(context);

        Assert.Equal(expectedStatus, context.Response.StatusCode);
        Assert.Equal(expectedContentRange ?? string.Empty,
            context.Response.Headers.ContentRange.ToString());
        Assert.Equal(expectedLength, context.Response.ContentLength);
        Assert.Equal("bytes", context.Response.Headers.AcceptRanges);
        Assert.Equal("audio/mpeg", context.Response.ContentType);
        Assert.Equal((expectedOffset, expectedLength), source.LastRange);
        Assert.True(source.Disposed);
        Assert.Equal(source.Bytes[(int)expectedOffset..(int)(expectedOffset + expectedLength)],
            ((MemoryStream)context.Response.Body).ToArray());
    }

    [Theory]
    [InlineData("bytes=10-")]
    [InlineData("bytes=0-1,3-4")]
    [InlineData("items=0-1")]
    public async Task SourceStreamResult_InvalidOrMultipleRangeReturns416WithoutReading(
        string range)
    {
        var source = new RecordingPreviewSource(new byte[10]);
        var context = Context(HttpMethods.Get, range);

        await new SourceStreamResult(source).ExecuteAsync(context);

        Assert.Equal(StatusCodes.Status416RangeNotSatisfiable, context.Response.StatusCode);
        Assert.Equal("bytes */10", context.Response.Headers.ContentRange);
        Assert.Null(source.LastRange);
        Assert.True(source.Disposed);
    }

    [Fact]
    public async Task SourceStreamResult_HeadWritesHeadersOnlyAndDoesNotExposeSourceReference()
    {
        var source = new RecordingPreviewSource(new byte[10]);
        var context = Context(HttpMethods.Head, null);

        await new SourceStreamResult(source).ExecuteAsync(context);

        Assert.Equal(StatusCodes.Status200OK, context.Response.StatusCode);
        Assert.Equal(10, context.Response.ContentLength);
        Assert.Null(source.LastRange);
        Assert.Empty(((MemoryStream)context.Response.Body).ToArray());
        Assert.DoesNotContain("/private/music", string.Join('\n',
            context.Response.Headers.Select(header => $"{header.Key}:{header.Value}")));
        Assert.True(source.Disposed);
    }

    [Fact]
    public async Task SourceStreamResult_ForwardsRequestCancellation()
    {
        var source = new RecordingPreviewSource(new byte[10]);
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var context = Context(HttpMethods.Get, null);
        context.RequestAborted = cancellation.Token;

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            new SourceStreamResult(source).ExecuteAsync(context));

        Assert.True(source.ObservedCancellation);
        Assert.True(source.Disposed);
    }

    [Fact]
    public async Task PreviewService_MountedSourceRevalidatesCapturedSnapshot()
    {
        using var directory = new TemporaryDirectory();
        var path = Path.Combine(directory.Path, "changed.mp3");
        await File.WriteAllBytesAsync(path, [1, 2, 3]);
        var captured = MusicImportScanner.NormalizeDatabaseTimestamp(File.GetLastWriteTimeUtc(path));
        await using var context = MusicImportScannerTests.CreateContext();
        var item = Item(MusicImportSourceKind.MountedDirectory, "changed.mp3", 3, captured, null);
        context.MusicImportItems.Add(item);
        await context.SaveChangesAsync();
        await File.WriteAllBytesAsync(path, [1, 2, 3, 4]);
        var settings = MusicImportScannerTests.EnabledSettings(directory.Path);
        var storage = new MissingPreviewStorage();
        var service = new MusicImportPreviewService(
            context,
            new MusicImportSourceReader(settings, storage),
            storage);

        await Assert.ThrowsAsync<MusicImportSourceChangedException>(() =>
            service.OpenAsync(item.Id));
    }

    [Fact]
    public async Task PreviewService_MissingStagingObjectFailsClosed()
    {
        await using var context = MusicImportScannerTests.CreateContext();
        var itemId = Guid.NewGuid();
        var reference = ImportObjectPath.BuildStaging(itemId, ".mp3");
        var item = Item(MusicImportSourceKind.BrowserStaging, reference, 3, null, "etag-1");
        item.Id = itemId;
        context.MusicImportItems.Add(item);
        await context.SaveChangesAsync();
        var storage = new MissingPreviewStorage();
        var settings = MusicImportScannerTests.EnabledSettings(Path.GetTempPath());
        var service = new MusicImportPreviewService(
            context,
            new MusicImportSourceReader(settings, storage),
            storage);

        await Assert.ThrowsAsync<MusicImportSourceChangedException>(() =>
            service.OpenAsync(item.Id));
    }

    private static DefaultHttpContext Context(string method, string? range)
    {
        var context = new DefaultHttpContext();
        context.Request.Method = method;
        if (range != null) context.Request.Headers.Range = range;
        context.Response.Body = new MemoryStream();
        return context;
    }

    private static MusicImportItem Item(
        MusicImportSourceKind kind,
        string reference,
        long length,
        DateTime? modifiedAt,
        string? etag) => new()
    {
        Batch = new MusicImportBatch
        {
            RequestedByUserId = Guid.NewGuid(),
            ClientRequestId = Guid.NewGuid().ToString("N"),
            SourceKind = kind,
            Status = MusicImportBatchStatus.AwaitingReview
        },
        SourceKind = kind,
        SourceReference = reference,
        StagingObjectPath = kind == MusicImportSourceKind.BrowserStaging ? reference : null,
        SourceETag = etag,
        RelativePath = reference,
        OriginalFileName = Path.GetFileName(reference),
        Extension = ".mp3",
        SizeBytes = length,
        SourceModifiedAt = modifiedAt ?? DateTime.UtcNow,
        Stage = MusicImportItemStage.Grouped
    };

    private sealed class RecordingPreviewSource(byte[] bytes) : IMusicImportPreviewSource
    {
        public byte[] Bytes { get; } = bytes;
        public long LengthBytes => Bytes.LongLength;
        public string ContentType => "audio/mpeg";
        public string? ETag => "preview-etag";
        public (long Offset, long Length)? LastRange { get; private set; }
        public bool ObservedCancellation { get; private set; }
        public bool Disposed { get; private set; }

        public async Task CopyRangeToAsync(
            long offset,
            long length,
            Stream destination,
            CancellationToken cancellationToken = default)
        {
            LastRange = (offset, length);
            ObservedCancellation = cancellationToken.IsCancellationRequested;
            cancellationToken.ThrowIfCancellationRequested();
            await destination.WriteAsync(
                Bytes.AsMemory((int)offset, (int)length),
                cancellationToken);
        }

        public ValueTask DisposeAsync()
        {
            Disposed = true;
            return ValueTask.CompletedTask;
        }
    }

    private sealed class MissingPreviewStorage : IStorageService
    {
        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) => Task.FromResult<StorageObjectMetadata?>(null);
        public Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) => throw new InvalidOperationException();
        public Task WriteObjectAsync(string filePath, Stream content, long length, string contentType, CancellationToken cancellationToken = default) => throw new InvalidOperationException();
        public Task<string> UploadFileAsync(Stream fileStream, string fileName, string folder, string? contentType = null) => throw new InvalidOperationException();
        public Task<Stream?> DownloadFileAsync(string filePath) => throw new InvalidOperationException();
        public Task<bool> DeleteFileAsync(string filePath) => throw new InvalidOperationException();
        public Task<string> GetFileUrlAsync(string filePath, TimeSpan? expiry = null) => throw new InvalidOperationException();
        public Task<bool> FileExistsAsync(string filePath) => throw new InvalidOperationException();
    }
}
