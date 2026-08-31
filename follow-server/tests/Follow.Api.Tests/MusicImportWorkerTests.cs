using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Options;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace Follow.Api.Tests;

public class MusicImportWorkerTests
{
    [Fact]
    public async Task ReadyToApplyBatch_TransitionsThenDispatchesOnlyLockedGroup()
    {
        using var source = new TemporaryDirectory();
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        var apply = new RecordingApplyService();
        await using var provider = CreateProvider(settings, applyService: apply);
        Guid batchId;
        Guid groupId;
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.ReadyToApply);
            var group = new MusicImportReviewGroup
            {
                Batch = batch,
                BatchId = batch.Id,
                Status = MusicImportReviewStatus.Locked
            };
            context.AddRange(batch, group);
            await context.SaveChangesAsync();
            batchId = batch.Id;
            groupId = group.Id;
        }
        var worker = CreateWorker(provider, settings, "apply-worker");

        Assert.True(await worker.RunIterationAsync());
        Assert.Equal(MusicImportBatchStatus.Applying,
            await GetBatchStatusAsync(provider, batchId));
        Assert.True(await worker.RunIterationAsync());

        Assert.Equal([(groupId, 0)], apply.Calls);
    }

    [Fact]
    public async Task PermanentApplyFailure_ReturnsGroupToReviewAndDoesNotRetryForever()
    {
        using var source = new TemporaryDirectory();
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        var apply = new ThrowingApplyService(
            new MusicImportApplyValidationException("Selected source SHA-256 changed."));
        await using var provider = CreateProvider(settings, applyService: apply);
        Guid batchId;
        Guid groupId;
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.Applying);
            var group = new MusicImportReviewGroup
            {
                Batch = batch,
                BatchId = batch.Id,
                Status = MusicImportReviewStatus.Locked
            };
            context.AddRange(batch, group);
            await context.SaveChangesAsync();
            batchId = batch.Id;
            groupId = group.Id;
        }
        var worker = CreateWorker(provider, settings, "failed-apply-worker");

        Assert.True(await worker.RunIterationAsync());
        Assert.False(await worker.RunIterationAsync());

        await using var verifyScope = provider.CreateAsyncScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var batchResult = await verify.MusicImportBatches.SingleAsync(batch => batch.Id == batchId);
        var groupResult = await verify.MusicImportReviewGroups.SingleAsync(group => group.Id == groupId);
        Assert.Equal(1, apply.CallCount);
        Assert.Equal(MusicImportBatchStatus.AwaitingReview, batchResult.Status);
        Assert.Equal("APPLY_VALIDATION_FAILED", batchResult.LastErrorCode);
        Assert.Equal(MusicImportReviewStatus.Open, groupResult.Status);
        Assert.Equal("APPLY_VALIDATION_FAILED", groupResult.ApplyErrorCode);
        Assert.Equal("Selected source SHA-256 changed.", groupResult.ApplyErrorMessage);
    }

    [Fact]
    public async Task TransientApplyFailure_PreservesDecisionForExplicitReapply()
    {
        using var source = new TemporaryDirectory();
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        var apply = new ThrowingApplyService(new IOException("storage unavailable"));
        await using var provider = CreateProvider(settings, applyService: apply);
        Guid groupId;
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.Applying);
            var group = new MusicImportReviewGroup
            {
                Batch = batch,
                BatchId = batch.Id,
                Status = MusicImportReviewStatus.Locked
            };
            context.AddRange(batch, group);
            await context.SaveChangesAsync();
            groupId = group.Id;
        }
        var worker = CreateWorker(provider, settings, "retryable-apply-worker");

        Assert.True(await worker.RunIterationAsync());

        await using var verifyScope = provider.CreateAsyncScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var groupResult = await verify.MusicImportReviewGroups.SingleAsync(group => group.Id == groupId);
        Assert.Equal(MusicImportReviewStatus.Confirmed, groupResult.Status);
        Assert.Equal("APPLY_IO_FAILED", groupResult.ApplyErrorCode);
        Assert.Equal("The selected audio could not be applied; confirm to retry.", groupResult.ApplyErrorMessage);
    }

    [Fact]
    public async Task AnalyzingBatch_CompletesEveryItemBeforeGroupingAndNeverCreatesTrack()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "one.mp3"), [1, 1, 1]);
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "two.mp3"), [2, 2, 2]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        var storage = new RecordingImportStorageService();
        await using var provider = CreateProvider(settings, storage);
        var batchId = await SeedBatchWithPendingItemsAsync(
            provider,
            source.Path,
            "one.mp3",
            "two.mp3",
            MusicImportBatchStatus.Analyzing);
        var worker = CreateWorker(provider, settings, "analysis-worker");

        Assert.True(await worker.RunIterationAsync());
        await using (var firstScope = provider.CreateAsyncScope())
        {
            var context = firstScope.ServiceProvider.GetRequiredService<FollowDbContext>();
            Assert.Single(await context.MusicImportItems.ToListAsync(),
                item => item.Stage == MusicImportItemStage.Analyzed);
            Assert.Empty(await context.MusicImportReviewGroups.ToListAsync());
            Assert.Empty(await context.Tracks.ToListAsync());
            Assert.Empty(storage.Writes);
        }

        Assert.True(await worker.RunIterationAsync());
        Assert.True(await worker.RunIterationAsync());
        Assert.True(await worker.RunIterationAsync());

        await using var scope = provider.CreateAsyncScope();
        var verify = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
        Assert.Equal(MusicImportBatchStatus.AwaitingReview,
            (await verify.MusicImportBatches.SingleAsync(batch => batch.Id == batchId)).Status);
        Assert.All(await verify.MusicImportItems.ToListAsync(),
            item => Assert.Equal(MusicImportItemStage.Grouped, item.Stage));
        Assert.Equal(2, await verify.MusicImportReviewGroups.CountAsync());
        Assert.Empty(await verify.Tracks.ToListAsync());
        Assert.Empty(storage.Writes);
    }

    [Fact]
    public async Task DisabledIteration_DoesNotInspectConfiguredSource()
    {
        var settings = new MusicImportRuntimeSettings
        {
            Enabled = false,
            SourceRoot = "/path-that-must-not-be-inspected"
        };
        await using var provider = CreateProvider(settings);
        var worker = CreateWorker(provider, settings, "disabled-worker");

        Assert.False(await worker.RunIterationAsync());
    }

    [Fact]
    public async Task PendingBatch_IsScannedButReadyWaitsForExplicitStart()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "scan.mp3"), [1]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        await using var provider = CreateProvider(settings);
        var batchId = await SeedBatchAsync(provider, MusicImportBatchStatus.Pending);
        var worker = CreateWorker(provider, settings, "scanner-worker");

        Assert.True(await worker.RunIterationAsync());
        Assert.False(await worker.RunIterationAsync());

        await using var scope = provider.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var batch = await context.MusicImportBatches.SingleAsync(item => item.Id == batchId);
        Assert.Equal(MusicImportBatchStatus.Ready, batch.Status);
        Assert.Null(batch.LeaseOwner);
        Assert.Single(await context.MusicImportItems.ToListAsync());
    }

    [Fact]
    public async Task ExpiredScanLease_RemainsScanningForAnotherWorkerToReclaim()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "slow-scan.mp3"), [1]);
        var settings = new MusicImportRuntimeSettings
        {
            Enabled = true,
            SourceRoot = source.Path,
            ScanBatchSize = 1,
            MaximumFileBytes = 1024,
            LeaseDuration = TimeSpan.FromTicks(1)
        };
        await using var provider = CreateProvider(settings);
        var batchId = await SeedBatchAsync(provider, MusicImportBatchStatus.Pending);
        var worker = CreateWorker(provider, settings, "expired-scanner");

        Assert.True(await worker.RunIterationAsync());

        Assert.Equal(
            MusicImportBatchStatus.Scanning,
            await GetBatchStatusAsync(provider, batchId));
    }


    [Fact]
    public async Task ExpiredProcessingLease_ReturnsItemToPendingForRestart()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "expired.mp3"), [1]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        await using var provider = CreateProvider(settings);
        Guid itemId;
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.Analyzing);
            var item = PendingItem(batch, source.Path, "expired.mp3");
            item.Status = MusicImportItemStatus.Processing;
            item.LeaseOwner = "dead-worker";
            item.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(-1);
            item.Stage = MusicImportItemStage.Hashing;
            itemId = item.Id;
            context.AddRange(batch, item);
            await context.SaveChangesAsync();
        }

        var worker = CreateWorker(provider, settings, "recovery-worker");
        Assert.True(await worker.RunIterationAsync());

        await using var verifyScope = provider.CreateAsyncScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var recovered = await verify.MusicImportItems.SingleAsync(item => item.Id == itemId);
        Assert.Equal(MusicImportItemStatus.Pending, recovered.Status);
        Assert.Equal(MusicImportItemStage.None, recovered.Stage);
        Assert.Null(recovered.LeaseOwner);
        Assert.Equal("LEASE_EXPIRED", recovered.ErrorCode);
    }

    [Fact]
    public async Task ExpiredUploadingLease_DefersReprocessingUntilLateWriteGraceElapses()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "uploading.mp3"), [1]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        var storage = new RecordingImportStorageService();
        await using var provider = CreateProvider(settings, storage);
        Guid itemId;
        string objectPath;
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.Running);
            var item = PendingItem(batch, source.Path, "uploading.mp3");
            item.Status = MusicImportItemStatus.Processing;
            item.Stage = MusicImportItemStage.Uploading;
            item.LeaseOwner = "expired-uploader";
            item.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(-1);
            objectPath = $"tracks/import/{item.Id}/audio.mp3";
            item.ObjectPath = objectPath;
            itemId = item.Id;
            context.AddRange(batch, item);
            await context.SaveChangesAsync();
        }

        var worker = CreateWorker(provider, settings, "upload-recovery");
        Assert.True(await worker.RunIterationAsync());
        Assert.False(await worker.RunIterationAsync());

        await using var verifyScope = provider.CreateAsyncScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var recovered = await verify.MusicImportItems.SingleAsync(item => item.Id == itemId);
        Assert.Equal(MusicImportItemStatus.Pending, recovered.Status);
        Assert.Equal("LEASE_EXPIRED_UPLOAD_GRACE", recovered.ErrorCode);
        Assert.Equal(objectPath, recovered.ObjectPath);
        Assert.True(recovered.NextAttemptAt > DateTime.UtcNow);
        Assert.Empty(storage.Deletes);
    }

    [Fact]
    public async Task PauseRequestedWithoutInflightWork_BecomesPaused()
    {
        using var source = new TemporaryDirectory();
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        await using var provider = CreateProvider(settings);
        var batchId = await SeedBatchAsync(provider, MusicImportBatchStatus.PauseRequested);

        var worker = CreateWorker(provider, settings, "pause-worker");
        Assert.True(await worker.RunIterationAsync());

        Assert.Equal(
            MusicImportBatchStatus.Paused,
            await GetBatchStatusAsync(provider, batchId));
    }

    [Fact]
    public async Task CancelRequested_CancelsUnstartedItemsWithoutDeletingImportedTracks()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "pending.mp3"), [1]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        await using var provider = CreateProvider(settings);
        var batchId = await SeedBatchWithPendingItemsAsync(
            provider,
            source.Path,
            "pending.mp3",
            status: MusicImportBatchStatus.CancelRequested);
        Guid importedItemId;
        Guid trackId;
        await using (var seedScope = provider.CreateAsyncScope())
        {
            var seed = seedScope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = await seed.MusicImportBatches.SingleAsync(item => item.Id == batchId);
            var track = new Track
            {
                Title = "Already imported",
                FilePath = "tracks/import/existing/audio.mp3"
            };
            var imported = PendingItem(batch, source.Path, "already-imported.mp3");
            imported.Status = MusicImportItemStatus.Imported;
            imported.Track = track;
            imported.TrackId = track.Id;
            imported.CompletedAt = DateTime.UtcNow;
            trackId = track.Id;
            importedItemId = imported.Id;
            seed.AddRange(track, imported);
            await seed.SaveChangesAsync();
        }

        var worker = CreateWorker(provider, settings, "cancel-worker");
        Assert.True(await worker.RunIterationAsync());

        await using var scope = provider.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
        Assert.Equal(
            MusicImportBatchStatus.Cancelled,
            (await context.MusicImportBatches.SingleAsync(batch => batch.Id == batchId)).Status);
        var items = await context.MusicImportItems.ToListAsync();
        Assert.Contains(items, item =>
            item.Id == importedItemId && item.Status == MusicImportItemStatus.Imported);
        Assert.Contains(items, item =>
            item.Id != importedItemId && item.Status == MusicImportItemStatus.Cancelled);
        Assert.Equal(trackId, (await context.Tracks.SingleAsync()).Id);
    }

    [Fact]
    public async Task CancelRequestedWithActiveLease_WaitsWithoutReportingHotLoopWork()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "active.mp3"), [1]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        await using var provider = CreateProvider(settings);
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.CancelRequested);
            var item = PendingItem(batch, source.Path, "active.mp3");
            item.Status = MusicImportItemStatus.Processing;
            item.LeaseOwner = "active-worker";
            item.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(10);
            context.AddRange(batch, item);
            await context.SaveChangesAsync();
        }

        var worker = CreateWorker(provider, settings, "waiting-canceller");

        Assert.False(await worker.RunIterationAsync());
    }

    [Fact]
    public async Task CancelRequestedWithActiveScanLease_WaitsBeforeCancellingPendingItems()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "pending.mp3"), [1]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        await using var provider = CreateProvider(settings);
        var batchId = await SeedBatchWithPendingItemsAsync(
            provider,
            source.Path,
            "pending.mp3",
            status: MusicImportBatchStatus.CancelRequested);
        await using (var seedScope = provider.CreateAsyncScope())
        {
            var seed = seedScope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = await seed.MusicImportBatches.SingleAsync(item => item.Id == batchId);
            batch.LeaseOwner = "active-scanner";
            batch.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(10);
            await seed.SaveChangesAsync();
        }

        var worker = CreateWorker(provider, settings, "cancel-peer");

        Assert.False(await worker.RunIterationAsync());

        await using var verifyScope = provider.CreateAsyncScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<FollowDbContext>();
        Assert.Equal(
            MusicImportBatchStatus.CancelRequested,
            (await verify.MusicImportBatches.SingleAsync()).Status);
        Assert.Equal(
            MusicImportItemStatus.Pending,
            (await verify.MusicImportItems.SingleAsync()).Status);
    }

    [Fact]
    public async Task CancelRequested_SafelyDeletesOnlyUntrackedDeterministicOrphan()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "orphan.mp3"), [1]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        var storage = new RecordingImportStorageService();
        await using var provider = CreateProvider(settings, storage);
        Guid batchId;
        Guid itemId;
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.CancelRequested);
            var item = PendingItem(batch, source.Path, "orphan.mp3");
            item.ObjectPath = $"tracks/import/{item.Id}/audio.mp3";
            batchId = batch.Id;
            itemId = item.Id;
            storage.Objects[item.ObjectPath] = [1];
            context.AddRange(batch, item);
            await context.SaveChangesAsync();
        }

        var worker = CreateWorker(provider, settings, "orphan-cleaner");
        Assert.True(await worker.RunIterationAsync());

        await using var verifyScope = provider.CreateAsyncScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var itemAfterCancel = await verify.MusicImportItems.SingleAsync(item => item.Id == itemId);
        Assert.Equal(MusicImportItemStatus.Cancelled, itemAfterCancel.Status);
        Assert.Null(itemAfterCancel.ObjectPath);
        Assert.Equal(MusicImportBatchStatus.Cancelled,
            (await verify.MusicImportBatches.SingleAsync(batch => batch.Id == batchId)).Status);
        Assert.Empty(storage.Objects);
        Assert.Empty(await verify.StorageDeletionJobs.ToListAsync());
    }

    [Fact]
    public async Task CancelCleanup_PreservesObjectReferencedByAnyTrackEvenWhenItemTrackIdIsMissing()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "referenced.mp3"), [1]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        var storage = new RecordingImportStorageService();
        await using var provider = CreateProvider(settings, storage);
        Guid itemId;
        Guid trackId;
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.CancelRequested);
            var item = PendingItem(batch, source.Path, "referenced.mp3");
            item.ObjectPath = $"tracks/import/{item.Id}/audio.mp3";
            var track = new Track { Title = "Referenced", FilePath = item.ObjectPath };
            itemId = item.Id;
            trackId = track.Id;
            storage.Objects[item.ObjectPath] = [1];
            context.AddRange(batch, item, track);
            await context.SaveChangesAsync();
        }

        var worker = CreateWorker(provider, settings, "reference-checker");
        Assert.True(await worker.RunIterationAsync());

        await using var verifyScope = provider.CreateAsyncScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var itemAfter = await verify.MusicImportItems.SingleAsync(item => item.Id == itemId);
        Assert.Equal(MusicImportItemStatus.Imported, itemAfter.Status);
        Assert.Equal(trackId, itemAfter.TrackId);
        Assert.Empty(storage.Deletes);
        Assert.Single(storage.Objects);
    }

    [Fact]
    public async Task CancelCleanup_InvalidDeterministicPathOrDeleteFailureStaysRetryableWithoutOutbox()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "unsafe.mp3"), [1]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        var storage = new RecordingImportStorageService { DeleteSucceeds = false };
        await using var provider = CreateProvider(settings, storage);
        Guid itemId;
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.CancelRequested);
            var item = PendingItem(batch, source.Path, "unsafe.mp3");
            item.ObjectPath = "tracks/import/different-item/audio.mp3";
            itemId = item.Id;
            context.AddRange(batch, item);
            await context.SaveChangesAsync();
        }

        var worker = CreateWorker(provider, settings, "safe-cleaner");
        Assert.True(await worker.RunIterationAsync());

        await using var verifyScope = provider.CreateAsyncScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var itemAfter = await verify.MusicImportItems.SingleAsync(item => item.Id == itemId);
        Assert.Equal(MusicImportItemStatus.Pending, itemAfter.Status);
        Assert.Equal("tracks/import/different-item/audio.mp3", itemAfter.ObjectPath);
        Assert.Equal("CLEANUP_UNSAFE", itemAfter.ErrorCode);
        Assert.Empty(storage.Deletes);
        Assert.Empty(await verify.StorageDeletionJobs.ToListAsync());
        Assert.Equal(
            MusicImportBatchStatus.CancelRequested,
            (await verify.MusicImportBatches.SingleAsync()).Status);
    }

    [Fact]
    public async Task CancelCleanup_GraceCatchesLateObjectFromExpiredUpload()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "late.mp3"), [5]);
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        var storage = new RecordingImportStorageService();
        await using var provider = CreateProvider(settings, storage);
        Guid itemId;
        string objectPath;
        await using (var scope = provider.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var batch = Batch(MusicImportBatchStatus.CancelRequested);
            var item = PendingItem(batch, source.Path, "late.mp3");
            item.Status = MusicImportItemStatus.Processing;
            item.Stage = MusicImportItemStage.Uploading;
            item.LeaseOwner = "expired-writer";
            item.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(-1);
            itemId = item.Id;
            objectPath = $"tracks/import/{item.Id}/audio.mp3";
            item.ObjectPath = objectPath;
            context.AddRange(batch, item);
            await context.SaveChangesAsync();
        }

        var worker = CreateWorker(provider, settings, "late-object-cleaner");
        Assert.True(await worker.RunIterationAsync());

        await using (var graceScope = provider.CreateAsyncScope())
        {
            var grace = graceScope.ServiceProvider.GetRequiredService<FollowDbContext>();
            var deferred = await grace.MusicImportItems.SingleAsync(item => item.Id == itemId);
            Assert.Equal(MusicImportItemStatus.Pending, deferred.Status);
            Assert.Equal("CLEANUP_GRACE", deferred.ErrorCode);
            Assert.Equal(objectPath, deferred.ObjectPath);
            Assert.True(deferred.NextAttemptAt > DateTime.UtcNow);
            Assert.Empty(storage.Deletes);

            // Simulate an old Put that ignored cancellation and became visible only
            // after the expired attempt had already been fenced out of the database.
            storage.Objects[objectPath] = [5];
            deferred.NextAttemptAt = DateTime.UtcNow.AddSeconds(-1);
            await grace.SaveChangesAsync();
        }

        Assert.True(await worker.RunIterationAsync());

        await using var verifyScope = provider.CreateAsyncScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var completed = await verify.MusicImportItems.SingleAsync(item => item.Id == itemId);
        Assert.Equal(MusicImportItemStatus.Cancelled, completed.Status);
        Assert.Null(completed.ObjectPath);
        Assert.Empty(storage.Objects);
        Assert.Empty(await verify.Tracks.ToListAsync());
        Assert.Equal(
            MusicImportBatchStatus.Cancelled,
            (await verify.MusicImportBatches.SingleAsync()).Status);
    }
    [Fact]
    public async Task VerifyingBatch_AfterRestartResumesTerminalization()
    {
        using var source = new TemporaryDirectory();
        var settings = MusicImportScannerTests.EnabledSettings(source.Path);
        await using var provider = CreateProvider(settings);
        var batchId = await SeedBatchAsync(provider, MusicImportBatchStatus.Verifying);

        var worker = CreateWorker(provider, settings, "restart-verifier");
        Assert.True(await worker.RunIterationAsync());

        Assert.Equal(
            MusicImportBatchStatus.Completed,
            await GetBatchStatusAsync(provider, batchId));
    }

    private static MusicImportWorker CreateWorker(
        ServiceProvider provider,
        MusicImportRuntimeSettings settings,
        string workerId) => new(
            provider.GetRequiredService<IServiceScopeFactory>(),
            settings,
            NullLogger<MusicImportWorker>.Instance,
            workerId);

    private static ServiceProvider CreateProvider(
        MusicImportRuntimeSettings settings,
        RecordingImportStorageService? storage = null,
        IMusicImportApplyService? applyService = null)
    {
        var services = new ServiceCollection();
        var databaseName = Guid.NewGuid().ToString();
        services.AddLogging();
        services.AddDbContext<FollowDbContext>(options =>
            options.UseInMemoryDatabase(databaseName));
        services.AddSingleton(settings);
        services.AddSingleton<IStorageService>(storage ?? new RecordingImportStorageService());
        services.AddSingleton<EmbeddedTrackAssetWriter>();
        services.AddSingleton<IAudioMetadataExtractor>(new RecordingMetadataExtractor(
            new AudioMetadata(
                "Worker title", null, null, 60, 192, "mp3",
                Codec: "mp3", Container: "mp3", IsLossless: false,
                SampleRateHz: 44_100, Channels: 2, BitRateKbps: 192,
                ExactDurationMilliseconds: 60_000)));
        services.AddSingleton<IAudioFingerprintService, WorkerFingerprintService>();
        services.AddScoped<IMusicImportSourceReader, MusicImportSourceReader>();
        services.AddSingleton(Options.Create(new AudioFingerprintOptions()));
        services.AddScoped<MusicImportScanner>();
        services.AddScoped<MusicImportAnalysisProcessor>();
        services.AddScoped<MusicImportGroupingService>();
        services.AddScoped<StorageDeletionQueue>();
        if (applyService == null)
            services.AddScoped<IMusicImportApplyService, MusicImportApplyService>();
        else
            services.AddSingleton(applyService);
        return services.BuildServiceProvider();
    }

    private static async Task<Guid> SeedBatchAsync(
        ServiceProvider provider,
        MusicImportBatchStatus status)
    {
        await using var scope = provider.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var batch = Batch(status);
        context.MusicImportBatches.Add(batch);
        await context.SaveChangesAsync();
        return batch.Id;
    }

    private static async Task<Guid> SeedBatchWithPendingItemsAsync(
        ServiceProvider provider,
        string sourceRoot,
        string first,
        string? second = null,
        MusicImportBatchStatus status = MusicImportBatchStatus.Running)
    {
        await using var scope = provider.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var batch = Batch(status);
        context.Add(batch);
        context.Add(PendingItem(batch, sourceRoot, first));
        if (second != null) context.Add(PendingItem(batch, sourceRoot, second));
        await context.SaveChangesAsync();
        return batch.Id;
    }

    private static MusicImportBatch Batch(MusicImportBatchStatus status) => new()
    {
        RequestedByUserId = Guid.NewGuid(),
        ClientRequestId = Guid.NewGuid().ToString("N"),
        Status = status
    };

    private static MusicImportItem PendingItem(
        MusicImportBatch batch,
        string sourceRoot,
        string relativePath)
    {
        var file = new FileInfo(Path.Combine(sourceRoot, relativePath));
        file.Refresh();
        return new MusicImportItem
        {
            Batch = batch,
            BatchId = batch.Id,
            SourceKind = MusicImportSourceKind.MountedDirectory,
            SourceReference = relativePath,
            RelativePath = relativePath,
            OriginalFileName = Path.GetFileName(relativePath),
            Extension = Path.GetExtension(relativePath),
            SizeBytes = file.Exists ? file.Length : 1,
            SourceModifiedAt = file.Exists
                ? MusicImportScanner.NormalizeDatabaseTimestamp(file.LastWriteTimeUtc)
                : DateTime.UtcNow,
            Status = MusicImportItemStatus.Pending,
            NextAttemptAt = DateTime.UtcNow.AddMinutes(-1)
        };
    }

    private static async Task<MusicImportBatchStatus> GetBatchStatusAsync(
        ServiceProvider provider,
        Guid batchId)
    {
        await using var scope = provider.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
        return await context.MusicImportBatches
            .Where(batch => batch.Id == batchId)
            .Select(batch => batch.Status)
            .SingleAsync();
    }
}

internal sealed class RecordingApplyService : IMusicImportApplyService
{
    public List<(Guid GroupId, int ExpectedVersion)> Calls { get; } = [];

    public Task<MusicImportApplyResult> ApplyGroupAsync(
        Guid groupId,
        int expectedVersion,
        CancellationToken cancellationToken = default)
    {
        Calls.Add((groupId, expectedVersion));
        return Task.FromResult(new MusicImportApplyResult(
            groupId,
            Guid.NewGuid(),
            false));
    }
}

internal sealed class ThrowingApplyService(Exception failure) : IMusicImportApplyService
{
    public int CallCount { get; private set; }

    public Task<MusicImportApplyResult> ApplyGroupAsync(
        Guid groupId,
        int expectedVersion,
        CancellationToken cancellationToken = default)
    {
        CallCount++;
        return Task.FromException<MusicImportApplyResult>(failure);
    }
}

internal sealed class WorkerFingerprintService : IAudioFingerprintService
{
    public Task<AudioFingerprintCapability> CheckCapabilityAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult(new AudioFingerprintCapability(true, "1.6.1", 2, null, null));

    public async Task<AudioFingerprint> ExtractAsync(
        Stream source,
        TimeSpan sourceDuration,
        CancellationToken cancellationToken = default)
    {
        var first = source.ReadByte();
        await Task.CompletedTask;
        return new AudioFingerprint(
            2,
            "1.6.1",
            sourceDuration,
            Enumerable.Repeat(unchecked((uint)first), 80).ToArray());
    }
}
