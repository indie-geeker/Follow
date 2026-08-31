using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Follow.Api.Tests;

public class MusicImportServiceTests
{
    [Fact]
    public async Task Create_IsIdempotentPerUserAndClientRequestId()
    {
        using var source = new TemporaryDirectory();
        await using var context = MusicImportScannerTests.CreateContext();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));
        var userId = Guid.NewGuid();
        var request = new CreateMusicImportRequest("stable-request", "", false);

        var first = await service.CreateBatchAsync(userId, request);
        var second = await service.CreateBatchAsync(userId, request);

        Assert.Equal(first.Id, second.Id);
        Assert.Equal("pending", first.Status);
        Assert.Single(await context.MusicImportBatches.ToListAsync());
    }

    [Fact]
    public async Task Create_IdempotencyKeyWithDifferentPayloadIsRejected()
    {
        using var source = new TemporaryDirectory();
        Directory.CreateDirectory(Path.Combine(source.Path, "other"));
        await using var context = MusicImportScannerTests.CreateContext();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));
        var userId = Guid.NewGuid();
        await service.CreateBatchAsync(
            userId,
            new CreateMusicImportRequest("same-key", "", false));

        var error = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CreateBatchAsync(
                userId,
                new CreateMusicImportRequest("same-key", "other", true)));

        Assert.Contains("payload", error.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Single(await context.MusicImportBatches.ToListAsync());
    }

    [Fact]
    public async Task ConcurrentCreateUniqueConflict_ReturnsTheWinningBatch()
    {
        using var source = new TemporaryDirectory();
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        await using var context = new RaceOnBatchSaveContext(options);
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));
        var userId = Guid.NewGuid();
        context.RaceNextBatchSave = true;

        var result = await service.CreateBatchAsync(
            userId,
            new CreateMusicImportRequest("concurrent-request", "", false));

        Assert.Equal(context.WinningBatchId, result.Id);
        await using var verify = new FollowDbContext(options);
        Assert.Single(await verify.MusicImportBatches.ToListAsync());
    }

    [Fact]
    public async Task Create_WhenDisabledRejectsBeforeAccessingSource()
    {
        await using var context = MusicImportScannerTests.CreateContext();
        var service = new MusicImportService(context, new MusicImportRuntimeSettings
        {
            Enabled = false,
            SourceRoot = "/path-that-must-not-be-inspected"
        });

        var error = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CreateBatchAsync(
                Guid.NewGuid(),
                new CreateMusicImportRequest("disabled", "", false)));

        Assert.Contains("disabled", error.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Empty(await context.MusicImportBatches.ToListAsync());
    }

    [Fact]
    public async Task CreateAndBrowserUpload_WhenFingerprintUnavailableFailClosed()
    {
        using var source = new TemporaryDirectory();
        await using var context = MusicImportScannerTests.CreateContext();
        var storage = new RecordingImportStorageService();
        var capability = new AudioFingerprintCapabilityState();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path),
            storage,
            capability);

        var directoryError = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CreateBatchAsync(
                Guid.NewGuid(),
                new CreateMusicImportRequest("fingerprint-gate-directory", "", false)));
        await using var upload = new MemoryStream([1, 2, 3]);
        var uploadError = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.CreateBrowserUploadAsync(
                Guid.NewGuid(),
                new BrowserMusicImportUpload(
                    upload,
                    "song.mp3",
                    "audio/mpeg",
                    upload.Length,
                    "fingerprint-gate-upload")));

        Assert.Contains("fingerprint", directoryError.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("fingerprint", uploadError.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Empty(await context.MusicImportBatches.ToListAsync());
        Assert.Empty(storage.Objects);
    }

    [Fact]
    public async Task StartPauseResumeAndCancel_EnforceExplicitStates()
    {
        using var source = new TemporaryDirectory();
        await using var context = MusicImportScannerTests.CreateContext();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));
        var batch = new MusicImportBatch
        {
            RequestedByUserId = Guid.NewGuid(),
            ClientRequestId = "control",
            Status = MusicImportBatchStatus.Pending
        };
        context.MusicImportBatches.Add(batch);
        await context.SaveChangesAsync();

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.StartAsync(batch.Id));

        batch.Status = MusicImportBatchStatus.Ready;
        await context.SaveChangesAsync();
        Assert.Equal("analyzing", (await service.StartAsync(batch.Id))!.Status);
        Assert.Equal("pauseRequested", (await service.PauseAsync(batch.Id))!.Status);

        batch.Status = MusicImportBatchStatus.Paused;
        await context.SaveChangesAsync();
        Assert.Equal("analyzing", (await service.ResumeAsync(batch.Id))!.Status);
        Assert.Equal("cancelRequested", (await service.CancelAsync(batch.Id))!.Status);
        Assert.NotNull(batch.CancelRequestedAt);
    }

    [Fact]
    public async Task RetryFailures_OnlyResetsRetryableItemsAndReturnsBatchToReady()
    {
        using var source = new TemporaryDirectory();
        await using var context = MusicImportScannerTests.CreateContext();
        var batch = new MusicImportBatch
        {
            RequestedByUserId = Guid.NewGuid(),
            ClientRequestId = "retry",
            Status = MusicImportBatchStatus.CompletedWithErrors,
            CompletedAt = DateTime.UtcNow
        };
        var retryable = Item(batch, "retry.mp3", MusicImportItemStatus.Failed, true);
        retryable.Stage = MusicImportItemStage.Uploading;
        retryable.ErrorCode = "STORAGE_ERROR";
        retryable.ErrorMessage = "temporary";
        var permanent = Item(batch, "permanent.mp3", MusicImportItemStatus.Failed, false);
        var imported = Item(batch, "done.mp3", MusicImportItemStatus.Imported, false);
        context.AddRange(batch, retryable, permanent, imported);
        await context.SaveChangesAsync();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));

        var result = await service.RetryFailuresAsync(batch.Id);

        Assert.Equal("ready", result!.Status);
        Assert.Equal(MusicImportItemStatus.Pending, retryable.Status);
        Assert.Equal(MusicImportItemStage.None, retryable.Stage);
        Assert.False(retryable.Retryable);
        Assert.Null(retryable.ErrorCode);
        Assert.Null(retryable.ErrorMessage);
        Assert.Equal(MusicImportItemStatus.Failed, permanent.Status);
        Assert.Equal(MusicImportItemStatus.Imported, imported.Status);
        Assert.Null(batch.CompletedAt);
    }

    [Fact]
    public async Task RetryFailures_LargeSetDoesNotRemainTrackedAfterBulkReset()
    {
        using var source = new TemporaryDirectory();
        await using var context = MusicImportScannerTests.CreateContext();
        var batch = Batch(
            Guid.NewGuid(),
            "large-retry",
            MusicImportBatchStatus.CompletedWithErrors);
        context.MusicImportBatches.Add(batch);
        for (var index = 0; index < 500; index++)
        {
            context.MusicImportItems.Add(Item(
                batch,
                $"retry-{index}.mp3",
                MusicImportItemStatus.Failed,
                retryable: true));
        }
        await context.SaveChangesAsync();
        context.ChangeTracker.Clear();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));

        var result = await service.RetryFailuresAsync(batch.Id);

        Assert.Equal("ready", result!.Status);
        Assert.Equal(
            500,
            await context.MusicImportItems.CountAsync(item =>
                item.Status == MusicImportItemStatus.Pending));
        Assert.Empty(context.ChangeTracker.Entries<MusicImportItem>());
    }

    [Fact]
    public async Task ControlConcurrencyFailure_IsTranslatedToStableConflict()
    {
        using var source = new TemporaryDirectory();
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        await using var context = new FailNextImportControlSaveContext(options);
        var batch = Batch(Guid.NewGuid(), "control-race", MusicImportBatchStatus.Ready);
        context.MusicImportBatches.Add(batch);
        await context.SaveChangesAsync();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));
        context.FailNextControlSave = true;

        var error = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.StartAsync(batch.Id));

        Assert.Contains("concurrent", error.Message, StringComparison.OrdinalIgnoreCase);
        Assert.IsType<DbUpdateConcurrencyException>(error.InnerException);
    }

    [Fact]
    public async Task ListsAndItems_AreFilterableAndPaginatedWithLowerCamelStatuses()
    {
        using var source = new TemporaryDirectory();
        await using var context = MusicImportScannerTests.CreateContext();
        var userId = Guid.NewGuid();
        var readyOne = Batch(userId, "ready-1", MusicImportBatchStatus.Ready);
        var running = Batch(userId, "running", MusicImportBatchStatus.Running);
        var readyTwo = Batch(userId, "ready-2", MusicImportBatchStatus.Ready);
        readyOne.CreatedAt = DateTime.UtcNow.AddMinutes(-2);
        running.CreatedAt = DateTime.UtcNow.AddMinutes(-1);
        readyTwo.CreatedAt = DateTime.UtcNow;
        context.AddRange(readyOne, running, readyTwo);
        context.AddRange(
            Item(readyTwo, "a.mp3", MusicImportItemStatus.Pending, false),
            Item(readyTwo, "b.mp3", MusicImportItemStatus.Failed, true),
            Item(readyTwo, "c.mp3", MusicImportItemStatus.Failed, false));
        await context.SaveChangesAsync();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));

        var batches = await service.GetBatchesAsync(1, 1, MusicImportBatchStatus.Ready);
        var items = await service.GetItemsAsync(
            readyTwo.Id,
            2,
            1,
            MusicImportItemStatus.Failed);

        Assert.Equal(2, batches.TotalCount);
        Assert.Equal(2, batches.TotalPages);
        Assert.Equal("ready-2", Assert.Single(batches.Batches).ClientRequestId);
        Assert.Equal(1, Assert.Single(batches.Batches).Progress.RetryableFailed);
        Assert.NotNull(items);
        Assert.Equal(2, items!.TotalCount);
        Assert.Equal(2, items.TotalPages);
        Assert.Equal("failed", Assert.Single(items.Items).Status);
    }

    [Fact]
    public async Task BatchReadModels_AggregateProgressWithoutTrackingEveryItem()
    {
        using var source = new TemporaryDirectory();
        await using var context = MusicImportScannerTests.CreateContext();
        var batch = Batch(Guid.NewGuid(), "aggregate", MusicImportBatchStatus.Running);
        context.MusicImportBatches.Add(batch);
        for (var index = 0; index < 25; index++)
        {
            context.MusicImportItems.Add(Item(
                batch,
                $"{index}.mp3",
                index < 10 ? MusicImportItemStatus.Imported : MusicImportItemStatus.Pending,
                false));
        }
        await context.SaveChangesAsync();
        context.ChangeTracker.Clear();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));

        var page = await service.GetBatchesAsync();
        var detail = await service.GetBatchAsync(batch.Id);

        Assert.Equal(10, Assert.Single(page.Batches).Progress.Imported);
        Assert.Equal(15, detail!.Progress.Pending);
        Assert.Empty(context.ChangeTracker.Entries<MusicImportItem>());
    }

    [Fact]
    public async Task BatchReadModels_AggregateEveryReviewPipelinePhase()
    {
        using var source = new TemporaryDirectory();
        await using var context = MusicImportScannerTests.CreateContext();
        var batch = Batch(Guid.NewGuid(), "phase-counts", MusicImportBatchStatus.Analyzing);
        context.MusicImportBatches.Add(batch);
        var stages = new[]
        {
            MusicImportItemStage.SourceValidation,
            MusicImportItemStage.Hashing,
            MusicImportItemStage.Metadata,
            MusicImportItemStage.Fingerprinting,
            MusicImportItemStage.Analyzed,
            MusicImportItemStage.Grouped,
            MusicImportItemStage.AwaitingReview,
            MusicImportItemStage.Applying,
            MusicImportItemStage.Verified
        };
        foreach (var stage in stages)
        {
            var item = Item(batch, $"{stage}.flac", MusicImportItemStatus.Processing, false);
            item.Stage = stage;
            context.MusicImportItems.Add(item);
        }
        await context.SaveChangesAsync();
        context.ChangeTracker.Clear();
        var service = new MusicImportService(
            context,
            MusicImportScannerTests.EnabledSettings(source.Path));

        var result = await service.GetBatchAsync(batch.Id);

        Assert.NotNull(result);
        Assert.Equal(1, result.Progress.Phases.SourceValidation);
        Assert.Equal(1, result.Progress.Phases.Hashing);
        Assert.Equal(1, result.Progress.Phases.Metadata);
        Assert.Equal(1, result.Progress.Phases.Fingerprinting);
        Assert.Equal(1, result.Progress.Phases.Analyzed);
        Assert.Equal(1, result.Progress.Phases.Grouped);
        Assert.Equal(1, result.Progress.Phases.AwaitingReview);
        Assert.Equal(1, result.Progress.Phases.Applying);
        Assert.Equal(1, result.Progress.Phases.Verified);
    }

    [Fact]
    public async Task ReviewReadModel_IsPagedAndExposesOnlySafeCompleteFacts()
    {
        await using var context = MusicImportScannerTests.CreateContext();
        var batch = Batch(Guid.NewGuid(), "review-page", MusicImportBatchStatus.AwaitingReview);
        var track = new Track
        {
            Title = "Existing",
            FilePath = "tracks/existing.flac",
            OriginalFileName = "existing.flac",
            Codec = "flac",
            Container = "flac",
            IsLossless = true,
            SampleRateHz = 96_000,
            BitDepth = 24,
            Channels = 2,
            BitRateKbps = 2_400,
            FileSizeBytes = 3_000,
            ExactDurationMilliseconds = 180_000
        };
        context.AddRange(batch, track);
        MusicImportReviewGroup? firstGroup = null;
        for (var index = 0; index < 3; index++)
        {
            var group = new MusicImportReviewGroup
            {
                Batch = batch,
                BatchId = batch.Id,
                ExistingTrack = index == 0 ? track : null,
                ExistingTrackId = index == 0 ? track.Id : null,
                Status = MusicImportReviewStatus.Open,
                MatchKind = MusicImportMatchKind.AcousticFingerprint,
                OverallSimilarity = .987,
                MinimumSegmentSimilarity = .95,
                CoverageFraction = .91,
                AlignmentOffsetFrames = 2,
                RecommendationExplanation = "无损格式且采样率更高",
                ApplyErrorCode = index == 0 ? "APPLY_RETRY" : null,
                ApplyErrorMessage = index == 0 ? "retry later" : null,
                CreatedAt = DateTime.UtcNow.AddMinutes(index)
            };
            var item = Item(batch, $"safe/candidate-{index}.flac", MusicImportItemStatus.Processing, false);
            item.SourceKind = MusicImportSourceKind.MountedDirectory;
            item.SourceReference = $"/private/source/candidate-{index}.flac";
            item.ReviewGroup = group;
            item.ReviewGroupId = group.Id;
            item.Codec = "flac";
            item.Container = "flac";
            item.IsLossless = true;
            item.SampleRateHz = 96_000;
            item.BitDepth = 24;
            item.Channels = 2;
            item.BitRateKbps = 2_400;
            item.ExactDurationMilliseconds = 180_000;
            group.RecommendedItemId = item.Id;
            context.AddRange(group, item);
            firstGroup ??= group;
        }
        var deletion = new StorageDeletionJob
        {
            ObjectPath = "tracks/old.flac",
            LastError = "storage timeout"
        };
        context.Add(deletion);
        context.Add(new TrackAudioRevision
        {
            Track = track,
            TrackId = track.Id,
            ReviewGroup = firstGroup!,
            ReviewGroupId = firstGroup!.Id,
            ActingUserId = Guid.NewGuid(),
            PreviousObjectPath = "tracks/old.flac",
            ReplacementObjectPath = "tracks/new.flac",
            StorageDeletionJob = deletion,
            StorageDeletionJobId = deletion.Id,
            CleanupStatus = TrackAudioRevisionCleanupStatus.Failed
        });
        await context.SaveChangesAsync();
        context.ChangeTracker.Clear();

        var page = await new MusicImportReviewService(context)
            .GetBatchReviewAsync(batch.Id, 1, 1);

        Assert.NotNull(page);
        Assert.Equal(3, page.TotalCount);
        Assert.Equal(3, page.TotalPages);
        Assert.Equal(3, page.Summary.Open);
        var groupDto = Assert.Single(page.Groups);
        Assert.Equal("acousticFingerprint", groupDto.MatchKind);
        Assert.False(string.IsNullOrWhiteSpace(groupDto.MatchExplanation));
        Assert.Equal("APPLY_RETRY", groupDto.ApplyErrorCode);
        Assert.Equal("failed", groupDto.CleanupStatus);
        Assert.Equal("STORAGE_CLEANUP_FAILED", groupDto.CleanupErrorCode);
        Assert.Equal("storage timeout", groupDto.CleanupErrorMessage);
        Assert.NotNull(groupDto.ExistingTrack);
        var candidate = Assert.Single(groupDto.Candidates);
        Assert.Equal("safe/candidate-0.flac", candidate.SourceLabel);
        Assert.True(candidate.PreviewAvailable);
        Assert.StartsWith("/api/admin/music-imports/items/", candidate.PreviewUrl);
        Assert.Null(groupDto.DecisionKind);
        Assert.Empty(groupDto.SelectedItemIds);
        var json = System.Text.Json.JsonSerializer.Serialize(page);
        Assert.DoesNotContain("/private/source", json, StringComparison.Ordinal);
        Assert.DoesNotContain("tracks/old.flac", json, StringComparison.Ordinal);
        Assert.DoesNotContain("tracks/new.flac", json, StringComparison.Ordinal);
    }

    private static MusicImportBatch Batch(
        Guid userId,
        string requestId,
        MusicImportBatchStatus status) => new()
    {
        RequestedByUserId = userId,
        ClientRequestId = requestId,
        Status = status
    };

    private static MusicImportItem Item(
        MusicImportBatch batch,
        string relativePath,
        MusicImportItemStatus status,
        bool retryable) => new()
    {
        Batch = batch,
        BatchId = batch.Id,
        RelativePath = relativePath,
        OriginalFileName = Path.GetFileName(relativePath),
        Extension = Path.GetExtension(relativePath),
        SizeBytes = 1,
        SourceModifiedAt = DateTime.UtcNow,
        Status = status,
        Retryable = retryable
    };
}

internal sealed class RaceOnBatchSaveContext : FollowDbContext
{
    private readonly DbContextOptions<FollowDbContext> _options;

    public RaceOnBatchSaveContext(DbContextOptions<FollowDbContext> options) : base(options)
    {
        _options = options;
    }

    public bool RaceNextBatchSave { get; set; }
    public Guid WinningBatchId { get; private set; }

    public override async Task<int> SaveChangesAsync(
        CancellationToken cancellationToken = default)
    {
        var attempted = ChangeTracker.Entries<MusicImportBatch>()
            .SingleOrDefault(entry => entry.State == EntityState.Added)?.Entity;
        if (!RaceNextBatchSave || attempted == null)
            return await base.SaveChangesAsync(cancellationToken);

        RaceNextBatchSave = false;
        Entry(attempted).State = EntityState.Detached;
        var winner = new MusicImportBatch
        {
            RequestedByUserId = attempted.RequestedByUserId,
            ClientRequestId = attempted.ClientRequestId,
            RelativeDirectory = attempted.RelativeDirectory,
            AutoStart = attempted.AutoStart
        };
        WinningBatchId = winner.Id;
        await using (var peer = new FollowDbContext(_options))
        {
            peer.MusicImportBatches.Add(winner);
            await peer.SaveChangesAsync(cancellationToken);
        }

        throw new DbUpdateException(
            "Forced concurrent unique conflict.",
            new PostgresException(
                "duplicate key",
                "ERROR",
                "ERROR",
                PostgresErrorCodes.UniqueViolation,
                constraintName: "UX_MusicImportBatches_RequestedByUser_ClientRequestId"));
    }
}

internal sealed class FailNextImportControlSaveContext : FollowDbContext
{
    public FailNextImportControlSaveContext(
        DbContextOptions<FollowDbContext> options) : base(options)
    {
    }

    public bool FailNextControlSave { get; set; }

    public override Task<int> SaveChangesAsync(
        CancellationToken cancellationToken = default)
    {
        if (FailNextControlSave &&
            ChangeTracker.Entries<MusicImportBatch>()
                .Any(entry => entry.State == EntityState.Modified))
        {
            FailNextControlSave = false;
            throw new DbUpdateConcurrencyException("Forced stale import control update.");
        }

        return base.SaveChangesAsync(cancellationToken);
    }
}
