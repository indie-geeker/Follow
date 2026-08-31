using System.Security.Cryptography;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace Follow.Api.Tests;

public class MusicImportProcessorTests
{
    private const string LeaseOwner = "worker-test";

    [Fact]
    public async Task ExactDuplicate_LinksExistingTrackWithoutWritingObject()
    {
        using var source = new TemporaryDirectory();
        var bytes = new byte[] { 1, 2, 3, 4 };
        var filePath = Path.Combine(source.Path, "duplicate.mp3");
        await File.WriteAllBytesAsync(filePath, bytes);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "duplicate.mp3");
        var existing = new Track
        {
            Title = "Existing",
            FilePath = "tracks/existing/audio.mp3",
            ContentSha256 = SHA256.HashData(bytes),
            FileSizeBytes = bytes.Length,
            OriginalFileName = "existing.mp3"
        };
        context.Tracks.Add(existing);
        await context.SaveChangesAsync();
        var storage = new RecordingImportStorageService();
        var processor = CreateProcessor(context, storage, source.Path);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        Assert.Equal(MusicImportItemStatus.Duplicate, item.Status);
        Assert.Equal(existing.Id, item.TrackId);
        Assert.Equal(SHA256.HashData(bytes), item.ContentSha256);
        Assert.Empty(storage.Writes);
        Assert.Empty(storage.Uploads);
        Assert.Single(await context.Tracks.ToListAsync());
    }

    [Fact]
    public async Task NewItem_WritesDeterministicObjectAndCommitsTrackWithTerminalItem()
    {
        using var source = new TemporaryDirectory();
        var bytes = new byte[] { 5, 4, 3, 2, 1 };
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "new.MP3"), bytes);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "new.MP3");
        var storage = new RecordingImportStorageService();
        var processor = CreateProcessor(context, storage, source.Path);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        var expectedPath = $"tracks/import/{item.Id}/audio.mp3";
        var track = Assert.Single(await context.Tracks.ToListAsync());
        Assert.Equal(expectedPath, Assert.Single(storage.Writes));
        Assert.Equal(bytes, storage.Objects[expectedPath]);
        Assert.Equal(expectedPath, track.FilePath);
        Assert.Equal("Metadata title", track.Title);
        Assert.Equal(bytes.Length, track.FileSizeBytes);
        Assert.Equal("new.MP3", track.OriginalFileName);
        Assert.Equal(SHA256.HashData(bytes), track.ContentSha256);
        var artist = Assert.Single(await context.Artists.ToListAsync());
        var album = Assert.Single(await context.Albums.ToListAsync());
        Assert.Equal("Metadata artist", artist.Name);
        Assert.Equal("Metadata album", album.Title);
        Assert.Equal(artist.Id, album.ArtistId);
        Assert.Equal(artist.Id, track.ArtistId);
        Assert.Equal(album.Id, track.AlbumId);
        Assert.Equal(MusicImportItemStatus.Imported, item.Status);
        Assert.Equal(MusicImportItemStage.None, item.Stage);
        Assert.Equal(track.Id, item.TrackId);
        Assert.Equal(expectedPath, item.ObjectPath);
        Assert.Null(item.LeaseOwner);
        Assert.NotNull(item.CompletedAt);
    }

    [Fact]
    public async Task NewItem_PersistsEmbeddedCoverAndLyricsWithTrack()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "assets.mp3"), [7, 8, 9]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "assets.mp3");
        var storage = new RecordingImportStorageService();
        var metadata = new RecordingMetadataExtractor(ValidMetadata with
        {
            CoverData = [1, 2],
            CoverContentType = "image/jpeg",
            TimedLyrics = "[00:01.20]line"
        });
        var processor = CreateProcessor(context, storage, source.Path, metadata);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        var track = await context.Tracks.SingleAsync();
        var coverUrl = Assert.IsType<string>(track.CoverUrl);
        var lyricsUrl = Assert.IsType<string>(track.LyricsUrl);
        Assert.Equal($"covers/{track.Id}/cover.jpg", coverUrl);
        Assert.Equal($"lyrics/{track.Id}/lyrics.lrc", lyricsUrl);
        Assert.Equal([coverUrl, lyricsUrl], storage.Uploads);
    }

    [Fact]
    public async Task EmbeddedAssetFailure_CleansAssetsAndAudioWithoutTrackReferences()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "asset-failure.mp3"), [7]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "asset-failure.mp3");
        var storage = new RecordingImportStorageService { FailUploadNumber = 2 };
        var metadata = new RecordingMetadataExtractor(ValidMetadata with
        {
            CoverData = [1],
            CoverContentType = "image/jpeg",
            TimedLyrics = "[00:01.20]line"
        });
        var processor = CreateProcessor(context, storage, source.Path, metadata);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        Assert.Equal(MusicImportItemStatus.Failed, item.Status);
        Assert.Equal("STORAGE_ERROR", item.ErrorCode);
        Assert.Empty(await context.Tracks.ToListAsync());
        Assert.Empty(storage.Objects);
        Assert.Contains(storage.Uploads.Single(path => path.StartsWith("covers/")), storage.Deletes);
        Assert.Contains($"tracks/import/{item.Id}/audio.mp3", storage.Deletes);
    }

    [Fact]
    public async Task DatabaseFailure_CleansEmbeddedAssetsAndAudio()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "asset-database.mp3"), [7]);
        var options = NewOptions();
        await using var context = new FailNextTrackSaveContext(options);
        var item = await SeedClaimedItemAsync(context, source.Path, "asset-database.mp3");
        context.FailNextTrackSave = true;
        var storage = new RecordingImportStorageService();
        var metadata = new RecordingMetadataExtractor(ValidMetadata with
        {
            CoverData = [1],
            CoverContentType = "image/png",
            TimedLyrics = "[00:01.20]line"
        });
        var processor = CreateProcessor(context, storage, source.Path, metadata);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        var persisted = await context.MusicImportItems.AsNoTracking()
            .SingleAsync(candidate => candidate.Id == item.Id);
        Assert.Equal(MusicImportItemStatus.Failed, persisted.Status);
        Assert.Equal("DATABASE_ERROR", persisted.ErrorCode);
        Assert.Empty(await context.Tracks.ToListAsync());
        Assert.Empty(storage.Objects);
        Assert.All(storage.Uploads, path => Assert.Contains(path, storage.Deletes));
        Assert.Contains($"tracks/import/{item.Id}/audio.mp3", storage.Deletes);
    }

    [Fact]
    public async Task DatabaseFailure_MarksRetryableAndImmediatelyDeletesDeterministicObject()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "database.mp3"), [1, 3, 5]);
        var options = NewOptions();
        await using var context = new FailNextTrackSaveContext(options);
        var item = await SeedClaimedItemAsync(context, source.Path, "database.mp3");
        context.FailNextTrackSave = true;
        var storage = new RecordingImportStorageService();
        var processor = CreateProcessor(context, storage, source.Path);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        var persisted = await context.MusicImportItems.AsNoTracking()
            .SingleAsync(candidate => candidate.Id == item.Id);
        var expectedPath = $"tracks/import/{item.Id}/audio.mp3";
        Assert.Equal(MusicImportItemStatus.Failed, persisted.Status);
        Assert.True(persisted.Retryable);
        Assert.Equal("DATABASE_ERROR", persisted.ErrorCode);
        Assert.Contains(expectedPath, storage.Deletes);
        Assert.DoesNotContain(expectedPath, storage.Objects.Keys);
        Assert.Empty(await context.StorageDeletionJobs.ToListAsync());
        Assert.Empty(await context.Tracks.ToListAsync());
    }

    [Fact]
    public async Task FailedImmediateCleanup_NeverQueuesADeletionThatCouldRaceRetry()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "cleanup.mp3"), [8, 8]);
        var options = NewOptions();
        await using var context = new FailNextTrackSaveContext(options);
        var item = await SeedClaimedItemAsync(context, source.Path, "cleanup.mp3");
        context.FailNextTrackSave = true;
        var storage = new RecordingImportStorageService { DeleteSucceeds = false };
        var processor = CreateProcessor(context, storage, source.Path);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        var deterministicPath = $"tracks/import/{item.Id}/audio.mp3";
        Assert.Contains(deterministicPath, storage.Objects.Keys);
        Assert.Contains(deterministicPath, storage.Deletes);
        Assert.Empty(await context.StorageDeletionJobs.ToListAsync());
    }

    [Fact]
    public async Task RecoveredObject_IsCleanedBeforeMissingSourceCanBecomeTerminal()
    {
        using var source = new TemporaryDirectory();
        var sourcePath = Path.Combine(source.Path, "recovered.mp3");
        await File.WriteAllBytesAsync(sourcePath, [4, 2]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "recovered.mp3");
        var objectPath = $"tracks/import/{item.Id}/audio.mp3";
        item.ObjectPath = objectPath;
        item.Stage = MusicImportItemStage.Persisting;
        await context.SaveChangesAsync();
        File.Delete(sourcePath);
        var storage = new RecordingImportStorageService();
        storage.Objects[objectPath] = [4, 2];
        var processor = CreateProcessor(context, storage, source.Path);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        var persisted = await context.MusicImportItems.AsNoTracking()
            .SingleAsync(candidate => candidate.Id == item.Id);
        Assert.Equal(MusicImportItemStatus.Failed, persisted.Status);
        Assert.Equal("SOURCE_MISSING", persisted.ErrorCode);
        Assert.Null(persisted.ObjectPath);
        Assert.Contains(objectPath, storage.Deletes);
        Assert.DoesNotContain(objectPath, storage.Objects.Keys);
    }

    [Fact]
    public async Task RecoveredObjectCleanupFailure_DefersRetryAndPreservesDurablePath()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "cleanup-retry.mp3"), [9]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "cleanup-retry.mp3");
        var objectPath = $"tracks/import/{item.Id}/audio.mp3";
        item.ObjectPath = objectPath;
        item.Stage = MusicImportItemStage.Persisting;
        await context.SaveChangesAsync();
        var storage = new RecordingImportStorageService { DeleteSucceeds = false };
        storage.Objects[objectPath] = [9];
        var processor = CreateProcessor(context, storage, source.Path);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        var persisted = await context.MusicImportItems.AsNoTracking()
            .SingleAsync(candidate => candidate.Id == item.Id);
        Assert.Equal(MusicImportItemStatus.Pending, persisted.Status);
        Assert.True(persisted.Retryable);
        Assert.Equal("CLEANUP_PENDING", persisted.ErrorCode);
        Assert.Equal(objectPath, persisted.ObjectPath);
        Assert.Empty(storage.Writes);
        Assert.Empty(await context.StorageDeletionJobs.ToListAsync());
    }

    [Fact]
    public async Task HeartbeatDuringDelayedWrite_PreventsAnotherWorkerFromReclaimingExpiredAttempt()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "delayed.mp3"), [7, 1]);
        var options = NewOptions();
        await using var context = new FollowDbContext(options);
        var item = await SeedClaimedItemAsync(context, source.Path, "delayed.mp3");
        var leaseDuration = TimeSpan.FromMilliseconds(450);
        item.LeaseExpiresAt = DateTime.UtcNow + leaseDuration;
        await context.SaveChangesAsync();
        var settings = Settings(source.Path, leaseDuration);
        var writeStarted = new TaskCompletionSource(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var releaseWrite = new TaskCompletionSource(
            TaskCreationOptions.RunContinuationsAsynchronously);
        var storage = new RecordingImportStorageService
        {
            AfterWriteAsync = async () =>
            {
                writeStarted.TrySetResult();
                await releaseWrite.Task;
            }
        };
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddScoped(_ => new FollowDbContext(options));
        services.AddSingleton<IStorageService>(storage);
        await using var provider = services.BuildServiceProvider();
        var processor = CreateProcessor(
            context,
            storage,
            source.Path,
            settings: settings,
            scopeFactory: provider.GetRequiredService<IServiceScopeFactory>());

        var processing = processor.ProcessAsync(item.Id, LeaseOwner);
        await writeStarted.Task.WaitAsync(TimeSpan.FromSeconds(5));
        await Task.Delay(leaseDuration + leaseDuration);

        var peerWorker = new MusicImportWorker(
            provider.GetRequiredService<IServiceScopeFactory>(),
            settings,
            NullLogger<MusicImportWorker>.Instance,
            "peer-worker");
        Assert.False(await peerWorker.RunIterationAsync());
        await using (var peer = new FollowDbContext(options))
        {
            var leased = await peer.MusicImportItems.SingleAsync(candidate => candidate.Id == item.Id);
            Assert.Equal(MusicImportItemStatus.Processing, leased.Status);
            Assert.Equal(LeaseOwner, leased.LeaseOwner);
            Assert.True(leased.LeaseExpiresAt > DateTime.UtcNow);
        }

        releaseWrite.TrySetResult();
        await processing;

        Assert.Equal(MusicImportItemStatus.Imported, item.Status);
        Assert.Single(storage.Objects);
        Assert.Empty(storage.Deletes);
    }

    [Fact]
    public async Task LostLeaseOwner_NeverDeletesObjectWrittenByTheNewOwner()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "owner-race.mp3"), [6, 6]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "owner-race.mp3");
        var storage = new RecordingImportStorageService
        {
            ThrowAfterWrite = true,
            AfterWriteAsync = async () =>
            {
                item.LeaseOwner = "new-owner";
                item.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(10);
                await context.SaveChangesAsync();
            }
        };
        var processor = CreateProcessor(context, storage, source.Path);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => processor.ProcessAsync(item.Id, LeaseOwner));

        var deterministicPath = $"tracks/import/{item.Id}/audio.mp3";
        Assert.Contains(deterministicPath, storage.Objects.Keys);
        Assert.Empty(storage.Deletes);
        Assert.Equal("new-owner", item.LeaseOwner);
    }

    [Fact]
    public async Task SourceSizeOrMtimeChange_FailsBeforeMetadataOrStorage()
    {
        using var source = new TemporaryDirectory();
        var filePath = Path.Combine(source.Path, "changed.mp3");
        await File.WriteAllBytesAsync(filePath, [1]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "changed.mp3");
        await using (var append = new FileStream(filePath, FileMode.Append, FileAccess.Write))
            await append.WriteAsync(new byte[] { 2 });
        var storage = new RecordingImportStorageService();
        var metadata = new RecordingMetadataExtractor(ValidMetadata);
        var processor = CreateProcessor(context, storage, source.Path, metadata);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        Assert.Equal(MusicImportItemStatus.Failed, item.Status);
        Assert.False(item.Retryable);
        Assert.Equal("SOURCE_CHANGED", item.ErrorCode);
        Assert.Equal(0, metadata.CallCount);
        Assert.Empty(storage.Writes);
    }

    [Fact]
    public async Task SourceChangeDetectedAfterWrite_ImmediatelyCleansTheObject()
    {
        using var source = new TemporaryDirectory();
        var filePath = Path.Combine(source.Path, "changed-after-write.mp3");
        await File.WriteAllBytesAsync(filePath, [1, 2]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(
            context,
            source.Path,
            "changed-after-write.mp3");
        var storage = new RecordingImportStorageService
        {
            AfterWriteAsync = () =>
            {
                File.SetLastWriteTimeUtc(filePath, DateTime.UtcNow.AddMinutes(1));
                return Task.CompletedTask;
            }
        };
        var processor = CreateProcessor(context, storage, source.Path);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        var objectPath = $"tracks/import/{item.Id}/audio.mp3";
        Assert.Equal(MusicImportItemStatus.Failed, item.Status);
        Assert.Equal("SOURCE_CHANGED", item.ErrorCode);
        Assert.Contains(objectPath, storage.Deletes);
        Assert.DoesNotContain(objectPath, storage.Objects.Keys);
    }

    [Fact]
    public async Task InvalidMetadata_FailsBeforeStorage()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "invalid.mp3"), [1]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "invalid.mp3");
        var storage = new RecordingImportStorageService();
        var metadata = new RecordingMetadataExtractor(
            new AudioMetadata("", null, null, 0, 0, ""));
        var processor = CreateProcessor(context, storage, source.Path, metadata);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        Assert.Equal(MusicImportItemStatus.Failed, item.Status);
        Assert.False(item.Retryable);
        Assert.Equal("INVALID_METADATA", item.ErrorCode);
        Assert.Empty(storage.Writes);
    }

    [Fact]
    public async Task AlbumWithoutArtist_IsImportedWithoutDereferencingMissingArtist()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "album-only.mp3"), [4]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "album-only.mp3");
        var storage = new RecordingImportStorageService();
        var metadata = new RecordingMetadataExtractor(
            ValidMetadata with { Artist = null, Album = "Compilation" });
        var processor = CreateProcessor(context, storage, source.Path, metadata);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        var track = Assert.Single(await context.Tracks.ToListAsync());
        var album = Assert.Single(await context.Albums.ToListAsync());
        Assert.Null(track.ArtistId);
        Assert.Null(album.ArtistId);
        Assert.Equal(album.Id, track.AlbumId);
    }

    [Fact]
    public async Task ProcessingTimeSymlink_IsRejectedEvenIfItemWasAlreadyScanned()
    {
        using var source = new TemporaryDirectory();
        using var outside = new TemporaryDirectory();
        var target = Path.Combine(outside.Path, "target.mp3");
        await File.WriteAllBytesAsync(target, [7]);
        File.CreateSymbolicLink(Path.Combine(source.Path, "linked.mp3"), target);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "linked.mp3");
        var storage = new RecordingImportStorageService();
        var processor = CreateProcessor(context, storage, source.Path);

        await processor.ProcessAsync(item.Id, LeaseOwner);

        Assert.Equal(MusicImportItemStatus.Failed, item.Status);
        Assert.Equal("SOURCE_REPARSE_POINT", item.ErrorCode);
        Assert.False(item.Retryable);
        Assert.Empty(storage.Writes);
    }

    [Fact]
    public async Task LeaseOwnerMismatch_CannotProcessClaimedItem()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "leased.mp3"), [1]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "leased.mp3");
        var storage = new RecordingImportStorageService();
        var processor = CreateProcessor(context, storage, source.Path);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => processor.ProcessAsync(item.Id, "different-worker"));

        Assert.Equal(MusicImportItemStatus.Processing, item.Status);
        Assert.Empty(storage.Writes);
    }

    [Fact]
    public async Task MissingLeaseExpiry_CannotProcessClaimedItem()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "missing-expiry.mp3"), [1]);
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, source.Path, "missing-expiry.mp3");
        item.LeaseExpiresAt = null;
        await context.SaveChangesAsync();
        var storage = new RecordingImportStorageService();
        var processor = CreateProcessor(context, storage, source.Path);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => processor.ProcessAsync(item.Id, LeaseOwner));

        Assert.Empty(storage.Writes);
    }

    private static readonly AudioMetadata ValidMetadata = new(
        "Metadata title",
        "Metadata artist",
        "Metadata album",
        180,
        320,
        "mp3");

    private static MusicImportProcessor CreateProcessor(
        FollowDbContext context,
        RecordingImportStorageService storage,
        string sourceRoot,
        IAudioMetadataExtractor? metadata = null,
        MusicImportRuntimeSettings? settings = null,
        IServiceScopeFactory? scopeFactory = null) => new(
        context,
        storage,
        metadata ?? new RecordingMetadataExtractor(ValidMetadata),
        new EmbeddedTrackAssetWriter(storage),
        settings ?? MusicImportScannerTests.EnabledSettings(sourceRoot),
            NullLogger<MusicImportProcessor>.Instance,
            scopeFactory);

    private static MusicImportRuntimeSettings Settings(
        string sourceRoot,
        TimeSpan leaseDuration) => new()
    {
        Enabled = true,
        SourceRoot = sourceRoot,
        ScanBatchSize = 2,
        MaximumFileBytes = 1024,
        LeaseDuration = leaseDuration
    };

    private static async Task<MusicImportItem> SeedClaimedItemAsync(
        FollowDbContext context,
        string sourceRoot,
        string relativePath)
    {
        var file = new FileInfo(Path.Combine(sourceRoot, relativePath));
        file.Refresh();
        var batch = new MusicImportBatch
        {
            RequestedByUserId = Guid.NewGuid(),
            ClientRequestId = Guid.NewGuid().ToString("N"),
            Status = MusicImportBatchStatus.Running
        };
        var item = new MusicImportItem
        {
            Batch = batch,
            BatchId = batch.Id,
            RelativePath = relativePath,
            OriginalFileName = Path.GetFileName(relativePath),
            Extension = Path.GetExtension(relativePath).ToLowerInvariant(),
            SizeBytes = file.Length,
            SourceModifiedAt = MusicImportScanner.NormalizeDatabaseTimestamp(file.LastWriteTimeUtc),
            Status = MusicImportItemStatus.Processing,
            LeaseOwner = LeaseOwner,
            LeaseExpiresAt = DateTime.UtcNow.AddMinutes(10),
            StartedAt = DateTime.UtcNow,
            AttemptCount = 1
        };
        context.AddRange(batch, item);
        await context.SaveChangesAsync();
        return item;
    }

    private static DbContextOptions<FollowDbContext> NewOptions() =>
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

    private static FollowDbContext CreateContext() => new(NewOptions());
}

internal sealed class RecordingMetadataExtractor : IAudioMetadataExtractor
{
    private readonly AudioMetadata _metadata;

    public RecordingMetadataExtractor(AudioMetadata metadata) => _metadata = metadata;

    public int CallCount { get; private set; }

    public Task<AudioMetadata> ExtractAsync(
        Stream source,
        string fileName,
        CancellationToken cancellationToken = default)
    {
        CallCount++;
        return Task.FromResult(_metadata);
    }
}

internal sealed class RecordingImportStorageService : IStorageService
{
    public Dictionary<string, byte[]> Objects { get; } = new(StringComparer.Ordinal);
    public List<string> Writes { get; } = [];
    public List<string> Uploads { get; } = [];
    public List<string> Deletes { get; } = [];
    public bool DeleteSucceeds { get; set; } = true;
    public bool ThrowAfterWrite { get; set; }
    public int? FailUploadNumber { get; init; }
    public Func<Task>? AfterWriteAsync { get; set; }

    public async Task WriteObjectAsync(
        string objectPath,
        Stream source,
        long length,
        string contentType,
        CancellationToken cancellationToken = default)
    {
        using var buffer = new MemoryStream();
        await source.CopyToAsync(buffer, cancellationToken);
        if (buffer.Length != length) throw new EndOfStreamException();
        Writes.Add(objectPath);
        Objects[objectPath] = buffer.ToArray();
        if (AfterWriteAsync != null) await AfterWriteAsync();
        if (ThrowAfterWrite) throw new IOException("Forced object write failure.");
    }

    public Task<string> UploadFileAsync(
        Stream fileStream,
        string fileName,
        string contentType,
        string? folder = null)
    {
        var objectPath = $"{folder}/{fileName}";
        Uploads.Add(objectPath);
        if (Uploads.Count == FailUploadNumber)
            throw new IOException("simulated embedded asset upload failure");
        using var buffer = new MemoryStream();
        fileStream.CopyTo(buffer);
        Objects[objectPath] = buffer.ToArray();
        return Task.FromResult(objectPath);
    }

    public Task<StorageObjectMetadata?> GetObjectMetadataAsync(
        string filePath,
        CancellationToken cancellationToken = default) => throw new NotSupportedException();

    public Task CopyRangeToAsync(
        string filePath,
        long offset,
        long length,
        Stream destination,
        CancellationToken cancellationToken = default) => throw new NotSupportedException();

    public Task<bool> DeleteFileAsync(string filePath)
    {
        Deletes.Add(filePath);
        if (DeleteSucceeds) Objects.Remove(filePath);
        return Task.FromResult(DeleteSucceeds);
    }
}

internal sealed class FailNextTrackSaveContext : FollowDbContext
{
    public FailNextTrackSaveContext(DbContextOptions<FollowDbContext> options) : base(options)
    {
    }

    public bool FailNextTrackSave { get; set; }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        if (FailNextTrackSave &&
            ChangeTracker.Entries<Track>().Any(entry => entry.State == EntityState.Added))
        {
            FailNextTrackSave = false;
            throw new InvalidOperationException("Forced database failure.");
        }

        return base.SaveChangesAsync(cancellationToken);
    }
}
