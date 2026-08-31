using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public class MusicImportBrowserUploadTests
{
    [Fact]
    public async Task Upload_StagesOneItemAndQueuesAnalysisWithoutCreatingTrack()
    {
        await using var context = MusicImportScannerTests.CreateContext();
        var storage = new BrowserUploadStorage();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings("/unused"),
            storage);
        var userId = Guid.NewGuid();

        var accepted = await service.CreateBrowserUploadAsync(
            userId,
            new BrowserMusicImportUpload(
                new MemoryStream([1, 2, 3]),
                "source.FLAC",
                "audio/flac",
                3,
                "browser-request"));

        var batch = await context.MusicImportBatches.SingleAsync();
        var item = await context.MusicImportItems.SingleAsync();
        Assert.Equal(batch.Id, accepted.BatchId);
        Assert.Equal(item.Id, accepted.ItemId);
        Assert.Equal(MusicImportSourceKind.BrowserStaging, batch.SourceKind);
        Assert.Equal(MusicImportBatchStatus.Analyzing, batch.Status);
        Assert.Equal(MusicImportSourceKind.BrowserStaging, item.SourceKind);
        var sourceReference = Assert.IsType<string>(item.SourceReference);
        Assert.Equal(ImportObjectPath.BuildStaging(item.Id, ".flac"), sourceReference);
        Assert.Equal(sourceReference, item.StagingObjectPath);
        Assert.Equal("etag-written", item.SourceETag);
        Assert.Empty(await context.Tracks.ToListAsync());
        Assert.Equal([sourceReference], storage.WrittenPaths);
    }

    [Theory]
    [InlineData("notes.txt", 3)]
    [InlineData("empty.mp3", 0)]
    [InlineData("large.mp3", 1025)]
    public async Task Upload_RejectsInvalidCandidateBeforeStorage(string fileName, long length)
    {
        await using var context = MusicImportScannerTests.CreateContext();
        var storage = new BrowserUploadStorage();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings("/unused"),
            storage);

        await Assert.ThrowsAnyAsync<ArgumentException>(() => service.CreateBrowserUploadAsync(
            Guid.NewGuid(),
            new BrowserMusicImportUpload(
                new MemoryStream(new byte[Math.Min(length, 1025)]),
                fileName,
                "application/octet-stream",
                length,
                "invalid")));

        Assert.Empty(storage.WrittenPaths);
        Assert.Empty(await context.MusicImportBatches.ToListAsync());
    }

    [Fact]
    public async Task Upload_CleansPartialObjectOnCancellationOrDatabaseFailure()
    {
        var storage = new BrowserUploadStorage { ThrowAfterWrite = new OperationCanceledException() };
        await using (var context = MusicImportScannerTests.CreateContext())
        {
            var service = new MusicImportService(
                context,
                MusicImportScannerTests.EnabledSettings("/unused"),
                storage);
            await Assert.ThrowsAnyAsync<OperationCanceledException>(() => service.CreateBrowserUploadAsync(
                Guid.NewGuid(),
                new BrowserMusicImportUpload(
                    new MemoryStream([1]), "cancel.mp3", "audio/mpeg", 1, "cancel")));
        }
        Assert.Equal(storage.WrittenPaths, storage.DeletedPaths);

        storage = new BrowserUploadStorage();
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        await using (var context = new RejectBrowserUploadSaveContext(options))
        {
            var service = new MusicImportService(
                context,
                MusicImportScannerTests.EnabledSettings("/unused"),
                storage);
            await Assert.ThrowsAsync<DbUpdateException>(() => service.CreateBrowserUploadAsync(
                Guid.NewGuid(),
                new BrowserMusicImportUpload(
                    new MemoryStream([1]), "db.mp3", "audio/mpeg", 1, "db")));
        }
        Assert.Equal(storage.WrittenPaths, storage.DeletedPaths);
    }
}

internal sealed class BrowserUploadStorage : IStorageService
{
    public Exception? ThrowAfterWrite { get; init; }
    public List<string> WrittenPaths { get; } = [];
    public List<string> DeletedPaths { get; } = [];
    public Dictionary<string, long> Lengths { get; } = [];

    public async Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default)
    {
        WrittenPaths.Add(objectPath);
        Lengths[objectPath] = length;
        var buffer = new byte[checked((int)length)];
        await source.ReadExactlyAsync(buffer, cancellationToken);
        if (ThrowAfterWrite != null) throw ThrowAfterWrite;
    }

    public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) =>
        Task.FromResult<StorageObjectMetadata?>(Lengths.TryGetValue(filePath, out var length)
            ? new(Length: length, ContentType: "audio/mpeg", ETag: "etag-written")
            : null);

    public Task<bool> DeleteFileAsync(string filePath)
    {
        DeletedPaths.Add(filePath);
        return Task.FromResult(true);
    }

    public Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null) => throw new NotSupportedException();
    public Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) => throw new NotSupportedException();
}

internal sealed class RejectBrowserUploadSaveContext : FollowDbContext
{
    public RejectBrowserUploadSaveContext(DbContextOptions<FollowDbContext> options) : base(options) { }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default) =>
        ChangeTracker.Entries<MusicImportItem>().Any(entry => entry.State == EntityState.Added)
            ? throw new DbUpdateException("simulated browser upload commit failure")
            : base.SaveChangesAsync(cancellationToken);
}
