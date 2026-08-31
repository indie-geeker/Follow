using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Follow.Infrastructure.Services;

public sealed class MusicImportWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly MusicImportRuntimeSettings _settings;
    private readonly ILogger<MusicImportWorker> _logger;
    private readonly string _workerId;

    public MusicImportWorker(
        IServiceScopeFactory scopeFactory,
        MusicImportRuntimeSettings settings,
        ILogger<MusicImportWorker> logger,
        string? workerId = null)
    {
        _scopeFactory = scopeFactory;
        _settings = settings;
        _logger = logger;
        _workerId = workerId ?? $"music-import-{Guid.NewGuid():N}";
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var didWork = false;
            try
            {
                didWork = await RunIterationAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    "Music import worker iteration failed: {ExceptionType}",
                    exception.GetType().Name);
            }

            if (didWork)
            {
                await Task.Yield();
                continue;
            }

            await Task.Delay(TimeSpan.FromSeconds(3), stoppingToken);
        }
    }

    public async Task<bool> RunIterationAsync(
        CancellationToken cancellationToken = default)
    {
        if (!_settings.Enabled) return false;

        await using var scope = _scopeFactory.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
        var storage = scope.ServiceProvider.GetRequiredService<IStorageService>();
        var now = DateTime.UtcNow;

        if (await HandleControlRequestsAsync(context, storage, now, cancellationToken)) return true;
        if (await RecoverExpiredItemAsync(context, now, cancellationToken)) return true;
        if (await CompleteVerifyingBatchAsync(context, cancellationToken)) return true;
        if (await StartReadyToApplyBatchAsync(context, cancellationToken)) return true;

        var applyGroup = await context.MusicImportReviewGroups
            .AsNoTracking()
            .Where(group => group.Status == MusicImportReviewStatus.Locked &&
                group.Batch.Status == MusicImportBatchStatus.Applying)
            .OrderBy(group => group.CreatedAt)
            .ThenBy(group => group.Id)
            .Select(group => new { group.Id, group.Version })
            .FirstOrDefaultAsync(cancellationToken);
        if (applyGroup != null)
        {
            var applyService = scope.ServiceProvider
                .GetRequiredService<IMusicImportApplyService>();
            try
            {
                await applyService.ApplyGroupAsync(
                    applyGroup.Id,
                    applyGroup.Version,
                    cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                var failure = ClassifyApplyFailure(exception);
                await ReturnApplyFailureToReviewAsync(
                    context,
                    applyGroup.Id,
                    failure,
                    cancellationToken);
                _logger.LogWarning(
                    "Music import apply failed for group {GroupId}: {ErrorCode} ({ExceptionType})",
                    applyGroup.Id,
                    failure.ErrorCode,
                    exception.GetType().Name);
            }
            return true;
        }

        if (await CompleteApplyingBatchAsync(context, cancellationToken)) return true;

        var scanBatchId = await TryClaimScanBatchAsync(context, now, cancellationToken);
        if (scanBatchId.HasValue)
        {
            var scanner = scope.ServiceProvider.GetRequiredService<MusicImportScanner>();
            try
            {
                await scanner.ScanAsync(scanBatchId.Value, _workerId, cancellationToken);
                var batch = await context.MusicImportBatches
                    .SingleAsync(candidate => candidate.Id == scanBatchId.Value, cancellationToken);
                if (batch.Status == MusicImportBatchStatus.Ready)
                {
                    batch.LeaseOwner = null;
                    batch.LeaseExpiresAt = null;
                    if (batch.AutoStart)
                    {
                        MusicImportStateMachine.EnsureTransition(
                            batch.Status,
                            MusicImportBatchStatus.Analyzing);
                        batch.Status = MusicImportBatchStatus.Analyzing;
                        batch.StartedAt ??= DateTime.UtcNow;
                    }
                    await context.SaveChangesAsync(cancellationToken);
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                _logger.LogWarning(
                    "Music import scan failed for batch {BatchId}: {ExceptionType}",
                    scanBatchId.Value,
                    exception.GetType().Name);
                await MarkScanFailedAsync(
                    context,
                    scanBatchId.Value,
                    "SCAN_FAILED",
                    cancellationToken);
            }
            return true;
        }

        if (await StartAutoReadyBatchAsync(context, cancellationToken)) return true;

        var analysisItemId = await TryClaimAnalysisItemAsync(context, now, cancellationToken);
        if (analysisItemId.HasValue)
        {
            try
            {
                var processor = scope.ServiceProvider
                    .GetRequiredService<MusicImportAnalysisProcessor>();
                await processor.AnalyzeAsync(
                    analysisItemId.Value,
                    _workerId,
                    cancellationToken);
            }
            catch (DbUpdateConcurrencyException)
            {
                _logger.LogWarning(
                    "Music import analysis item {ItemId} lease changed during processing",
                    analysisItemId.Value);
            }
            catch (InvalidOperationException)
            {
                _logger.LogWarning(
                    "Music import analysis item {ItemId} is no longer owned by this worker",
                    analysisItemId.Value);
            }
            return true;
        }

        if (await TryStartGroupingAsync(context, cancellationToken)) return true;

        var groupingBatchId = await context.MusicImportBatches
            .Where(batch => batch.Status == MusicImportBatchStatus.Grouping)
            .OrderBy(batch => batch.CreatedAt)
            .ThenBy(batch => batch.Id)
            .Select(batch => (Guid?)batch.Id)
            .FirstOrDefaultAsync(cancellationToken);
        if (groupingBatchId.HasValue)
        {
            var grouping = scope.ServiceProvider
                .GetRequiredService<MusicImportGroupingService>();
            await grouping.GroupBatchAsync(groupingBatchId.Value, cancellationToken);
            return true;
        }

        return false;
    }

    private async Task<bool> HandleControlRequestsAsync(
        FollowDbContext context,
        IStorageService storage,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var cancelBatch = await context.MusicImportBatches
            .OrderBy(batch => batch.CreatedAt)
            .FirstOrDefaultAsync(
                batch => batch.Status == MusicImportBatchStatus.CancelRequested,
                cancellationToken);
        if (cancelBatch != null)
        {
            if (cancelBatch.LeaseOwner != null && cancelBatch.LeaseExpiresAt > now)
                return false;

            var stagingCleanupAttempted = await TryCleanupCancelledStagingAsync(
                context,
                storage,
                cancelBatch.Id,
                now,
                cancellationToken);
            var cleanupAttempted = stagingCleanupAttempted || await TryCleanupCancelledObjectAsync(
                context,
                storage,
                cancelBatch.Id,
                now,
                cancellationToken);

            int cancelledCount;
            if (context.Database.IsRelational())
            {
                cancelledCount = await context.MusicImportItems
                    .Where(item => item.BatchId == cancelBatch.Id &&
                        !(item.TrackId == null &&
                          (item.ObjectPath != null ||
                           (item.SourceKind == MusicImportSourceKind.BrowserStaging &&
                            item.StagingObjectPath != null))) &&
                        (item.Status == MusicImportItemStatus.Pending ||
                         (item.Status == MusicImportItemStatus.Processing &&
                          (item.LeaseExpiresAt == null || item.LeaseExpiresAt <= now))))
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(item => item.Status, MusicImportItemStatus.Cancelled)
                        .SetProperty(item => item.Stage, MusicImportItemStage.None)
                        .SetProperty(item => item.Retryable, false)
                        .SetProperty(item => item.LeaseOwner, (string?)null)
                        .SetProperty(item => item.LeaseExpiresAt, (DateTime?)null)
                        .SetProperty(item => item.ErrorCode, (string?)null)
                        .SetProperty(item => item.ErrorMessage, (string?)null)
                        .SetProperty(item => item.CompletedAt, now)
                        .SetProperty(item => item.UpdatedAt, now)
                        .SetProperty(item => item.Version, item => item.Version + 1),
                        cancellationToken);
            }
            else
            {
                var pendingItems = await context.MusicImportItems
                    .Where(item => item.BatchId == cancelBatch.Id &&
                        !(item.TrackId == null &&
                          (item.ObjectPath != null ||
                           (item.SourceKind == MusicImportSourceKind.BrowserStaging &&
                            item.StagingObjectPath != null))) &&
                        (item.Status == MusicImportItemStatus.Pending ||
                         (item.Status == MusicImportItemStatus.Processing &&
                          (item.LeaseExpiresAt == null || item.LeaseExpiresAt <= now))))
                    .ToListAsync(cancellationToken);
                foreach (var item in pendingItems)
                {
                    item.Status = MusicImportItemStatus.Cancelled;
                    item.Stage = MusicImportItemStage.None;
                    item.Retryable = false;
                    item.LeaseOwner = null;
                    item.LeaseExpiresAt = null;
                    item.ErrorCode = null;
                    item.ErrorMessage = null;
                    item.CompletedAt = now;
                }
                cancelledCount = pendingItems.Count;
                if (cancelledCount > 0)
                    await context.SaveChangesAsync(cancellationToken);
            }

            var hasInflight = await context.MusicImportItems.AnyAsync(
                item => item.BatchId == cancelBatch.Id &&
                    item.Status == MusicImportItemStatus.Processing &&
                    item.LeaseExpiresAt > now,
                cancellationToken);
            var hasCleanupPending = await context.MusicImportItems.AnyAsync(
                item => item.BatchId == cancelBatch.Id &&
                    item.TrackId == null &&
                    (item.ObjectPath != null ||
                     (item.SourceKind == MusicImportSourceKind.BrowserStaging &&
                      item.StagingObjectPath != null)) &&
                    (item.Status == MusicImportItemStatus.Pending ||
                     item.Status == MusicImportItemStatus.Processing),
                cancellationToken);
            if (!hasInflight && !hasCleanupPending)
            {
                MusicImportStateMachine.EnsureTransition(
                    cancelBatch.Status,
                    MusicImportBatchStatus.Cancelled);
                cancelBatch.Status = MusicImportBatchStatus.Cancelled;
                cancelBatch.CompletedAt = now;
                cancelBatch.LeaseOwner = null;
                cancelBatch.LeaseExpiresAt = null;
                await context.SaveChangesAsync(cancellationToken);
                return true;
            }
            return cleanupAttempted || cancelledCount > 0;
        }

        var pauseBatch = await context.MusicImportBatches
            .OrderBy(batch => batch.CreatedAt)
            .FirstOrDefaultAsync(
                batch => batch.Status == MusicImportBatchStatus.PauseRequested,
                cancellationToken);
        if (pauseBatch == null) return false;

        var hasProcessing = await context.MusicImportItems.AnyAsync(
            item => item.BatchId == pauseBatch.Id &&
                item.Status == MusicImportItemStatus.Processing,
            cancellationToken);
        if (hasProcessing) return false;

        MusicImportStateMachine.EnsureTransition(
            pauseBatch.Status,
            MusicImportBatchStatus.Paused);
        pauseBatch.Status = MusicImportBatchStatus.Paused;
        await context.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task<bool> TryCleanupCancelledStagingAsync(
        FollowDbContext context,
        IStorageService storage,
        Guid batchId,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var item = await context.MusicImportItems
            .OrderBy(candidate => candidate.NextAttemptAt)
            .ThenBy(candidate => candidate.CreatedAt)
            .ThenBy(candidate => candidate.Id)
            .FirstOrDefaultAsync(candidate =>
                candidate.BatchId == batchId &&
                candidate.SourceKind == MusicImportSourceKind.BrowserStaging &&
                candidate.TrackId == null &&
                candidate.StagingObjectPath != null &&
                ((candidate.Status == MusicImportItemStatus.Pending &&
                  candidate.NextAttemptAt <= now) ||
                 (candidate.Status == MusicImportItemStatus.Processing &&
                  (candidate.LeaseExpiresAt == null || candidate.LeaseExpiresAt <= now))),
                cancellationToken);
        if (item == null) return false;

        var stagingPath = item.StagingObjectPath!;
        try
        {
            ImportObjectPath.Validate(stagingPath);
            if (!ImportObjectPath.IsStaging(stagingPath) ||
                !string.Equals(item.SourceReference, stagingPath, StringComparison.Ordinal))
            {
                throw new ArgumentException("Browser staging references do not match.");
            }

            if (!await storage.DeleteFileAsync(stagingPath))
            {
                MarkCleanupRetry(
                    item,
                    now,
                    "STAGING_CLEANUP_PENDING",
                    "The browser staging object could not be deleted and cleanup will be retried.");
                await context.SaveChangesAsync(cancellationToken);
                return true;
            }

            item.SourceReference = null;
            item.StagingObjectPath = null;
            item.SourceETag = null;
            item.Status = MusicImportItemStatus.Cancelled;
            item.Stage = MusicImportItemStage.None;
            item.Retryable = false;
            item.LeaseOwner = null;
            item.LeaseExpiresAt = null;
            item.ErrorCode = null;
            item.ErrorMessage = null;
            item.CompletedAt = now;
            await context.SaveChangesAsync(cancellationToken);
            return true;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                "Browser staging cleanup failed for item {ItemId}: {ExceptionType}",
                item.Id,
                exception.GetType().Name);
            MarkCleanupRetry(
                item,
                now,
                "STAGING_CLEANUP_PENDING",
                "The browser staging object could not be deleted and cleanup will be retried.");
            await context.SaveChangesAsync(CancellationToken.None);
            return true;
        }
    }

    private async Task<bool> TryCleanupCancelledObjectAsync(
        FollowDbContext context,
        IStorageService storage,
        Guid batchId,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var candidate = await context.MusicImportItems
            .AsNoTracking()
            .Where(item => item.BatchId == batchId &&
                item.TrackId == null &&
                (item.ObjectPath != null ||
                 (item.Status == MusicImportItemStatus.Processing &&
                  (item.Stage == MusicImportItemStage.Uploading ||
                   item.Stage == MusicImportItemStage.Persisting))) &&
                ((item.Status == MusicImportItemStatus.Pending &&
                  item.NextAttemptAt <= now) ||
                 (item.Status == MusicImportItemStatus.Processing &&
                  (item.LeaseExpiresAt == null || item.LeaseExpiresAt <= now))))
            .OrderBy(item => item.NextAttemptAt)
            .ThenBy(item => item.CreatedAt)
            .ThenBy(item => item.Id)
            .Select(item => new
            {
                item.Id,
                item.Version,
                item.ObjectPath,
                item.Extension,
                item.Stage
            })
            .FirstOrDefaultAsync(cancellationToken);
        if (candidate == null) return false;

        var expectedPath = BuildObjectPath(candidate.Id, candidate.Extension);
        var objectPath = candidate.ObjectPath ?? expectedPath;
        var leaseExpiresAt = now + _settings.LeaseDuration;

        if (context.Database.IsRelational())
        {
            var claimed = await context.MusicImportItems
                .Where(item => item.Id == candidate.Id &&
                    item.Version == candidate.Version &&
                    item.BatchId == batchId &&
                    item.TrackId == null &&
                    (item.ObjectPath != null ||
                     (item.Status == MusicImportItemStatus.Processing &&
                      (item.Stage == MusicImportItemStage.Uploading ||
                       item.Stage == MusicImportItemStage.Persisting))) &&
                    ((item.Status == MusicImportItemStatus.Pending &&
                      item.NextAttemptAt <= now) ||
                     (item.Status == MusicImportItemStatus.Processing &&
                      (item.LeaseExpiresAt == null || item.LeaseExpiresAt <= now))))
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(item => item.Status, MusicImportItemStatus.Processing)
                    .SetProperty(item => item.ObjectPath, objectPath)
                    .SetProperty(item => item.LeaseOwner, _workerId)
                    .SetProperty(item => item.LeaseExpiresAt, leaseExpiresAt)
                    .SetProperty(item => item.UpdatedAt, now)
                    .SetProperty(item => item.Version, item => item.Version + 1),
                    cancellationToken);
            if (claimed != 1) return false;
        }
        else
        {
            var tracked = await context.MusicImportItems.SingleAsync(
                item => item.Id == candidate.Id,
                cancellationToken);
            if (tracked.Version != candidate.Version ||
                tracked.BatchId != batchId ||
                tracked.TrackId != null ||
                (tracked.ObjectPath == null &&
                 (tracked.Status != MusicImportItemStatus.Processing ||
                  (tracked.Stage != MusicImportItemStage.Uploading &&
                   tracked.Stage != MusicImportItemStage.Persisting))) ||
                (tracked.Status == MusicImportItemStatus.Pending
                    ? tracked.NextAttemptAt > now
                    : tracked.Status != MusicImportItemStatus.Processing ||
                      tracked.LeaseExpiresAt > now))
            {
                return false;
            }

            tracked.Status = MusicImportItemStatus.Processing;
            tracked.ObjectPath = objectPath;
            tracked.LeaseOwner = _workerId;
            tracked.LeaseExpiresAt = leaseExpiresAt;
            try
            {
                await context.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateConcurrencyException)
            {
                return false;
            }
        }

        var item = await context.MusicImportItems.SingleAsync(
            current => current.Id == candidate.Id,
            cancellationToken);
        if (item.LeaseOwner != _workerId ||
            item.Status != MusicImportItemStatus.Processing ||
            item.LeaseExpiresAt <= now)
        {
            return false;
        }

        if (!string.Equals(item.ObjectPath, expectedPath, StringComparison.Ordinal) ||
            !IsValidManagedImportPath(item.ObjectPath))
        {
            MarkCleanupRetry(
                item,
                now,
                "CLEANUP_UNSAFE",
                "The managed object path could not be verified for safe cleanup.");
            await context.SaveChangesAsync(cancellationToken);
            return true;
        }

        var referencedTrack = await context.Tracks
            .OrderBy(track => track.CreatedAt)
            .FirstOrDefaultAsync(
                track => track.FilePath == item.ObjectPath,
                cancellationToken);
        if (referencedTrack != null)
        {
            MarkImported(item, referencedTrack.Id, now);
            await context.SaveChangesAsync(cancellationToken);
            return true;
        }

        if (candidate.Stage == MusicImportItemStage.Uploading)
        {
            var graceDelay = _settings.LeaseDuration > TimeSpan.FromMinutes(1)
                ? _settings.LeaseDuration
                : TimeSpan.FromMinutes(1);
            MarkCleanupRetry(
                item,
                now,
                "CLEANUP_GRACE",
                "Cleanup was deferred to fence a possibly incomplete managed object write.",
                graceDelay);
            await context.SaveChangesAsync(cancellationToken);
            return true;
        }

        var managedObjectPath = item.ObjectPath!;
        try
        {
            if (!await storage.DeleteFileAsync(managedObjectPath))
            {
                MarkCleanupRetry(
                    item,
                    now,
                    "CLEANUP_PENDING",
                    "The managed object could not be deleted and cleanup will be retried.");
                await context.SaveChangesAsync(cancellationToken);
                return true;
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                "Music import cancellation cleanup failed for item {ItemId}: {ExceptionType}",
                item.Id,
                exception.GetType().Name);
            MarkCleanupRetry(
                item,
                now,
                "CLEANUP_PENDING",
                "The managed object could not be deleted and cleanup will be retried.");
            await context.SaveChangesAsync(cancellationToken);
            return true;
        }

        item.Status = MusicImportItemStatus.Cancelled;
        item.Stage = MusicImportItemStage.None;
        item.Retryable = false;
        item.ObjectPath = null;
        item.LeaseOwner = null;
        item.LeaseExpiresAt = null;
        item.ErrorCode = null;
        item.ErrorMessage = null;
        item.CompletedAt = now;
        await context.SaveChangesAsync(cancellationToken);
        return true;
    }

    private static string BuildObjectPath(Guid itemId, string extension) =>
        $"tracks/import/{itemId}/audio{extension.ToLowerInvariant()}";

    private static bool IsValidManagedImportPath(string? objectPath)
    {
        if (objectPath == null) return false;
        try
        {
            MinioStorageService.ValidateImportObjectPath(objectPath);
            return true;
        }
        catch (ArgumentException)
        {
            return false;
        }
    }

    private static void MarkCleanupRetry(
        MusicImportItem item,
        DateTime now,
        string errorCode,
        string errorMessage,
        TimeSpan? retryDelay = null)
    {
        item.Status = MusicImportItemStatus.Pending;
        item.Stage = MusicImportItemStage.None;
        item.Retryable = true;
        item.NextAttemptAt = now + (retryDelay ?? TimeSpan.FromMinutes(1));
        item.LeaseOwner = null;
        item.LeaseExpiresAt = null;
        item.ErrorCode = errorCode;
        item.ErrorMessage = errorMessage;
        item.StartedAt = null;
        item.CompletedAt = null;
    }

    private static void MarkImported(
        MusicImportItem item,
        Guid trackId,
        DateTime now)
    {
        item.Status = MusicImportItemStatus.Imported;
        item.Stage = MusicImportItemStage.None;
        item.Retryable = false;
        item.TrackId = trackId;
        item.LeaseOwner = null;
        item.LeaseExpiresAt = null;
        item.ErrorCode = null;
        item.ErrorMessage = null;
        item.CompletedAt = now;
    }

    private async Task<bool> RecoverExpiredItemAsync(
        FollowDbContext context,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var item = await context.MusicImportItems
            .Include(candidate => candidate.Batch)
            .OrderBy(candidate => candidate.LeaseExpiresAt)
            .FirstOrDefaultAsync(candidate =>
                candidate.Status == MusicImportItemStatus.Processing &&
                (candidate.LeaseExpiresAt == null || candidate.LeaseExpiresAt <= now) &&
                (candidate.Batch.Status == MusicImportBatchStatus.Running ||
                 candidate.Batch.Status == MusicImportBatchStatus.Analyzing ||
                 candidate.Batch.Status == MusicImportBatchStatus.PauseRequested),
                cancellationToken);
        if (item == null) return false;

        var interruptedUpload = item.Stage == MusicImportItemStage.Uploading;
        if (item.ObjectPath == null &&
            (item.Stage == MusicImportItemStage.Uploading ||
             item.Stage == MusicImportItemStage.Persisting))
        {
            item.ObjectPath = BuildObjectPath(item.Id, item.Extension);
        }
        item.Status = MusicImportItemStatus.Pending;
        item.Stage = MusicImportItemStage.None;
        item.Retryable = interruptedUpload;
        item.NextAttemptAt = interruptedUpload
            ? now + (_settings.LeaseDuration > TimeSpan.FromMinutes(1)
                ? _settings.LeaseDuration
                : TimeSpan.FromMinutes(1))
            : now;
        item.LeaseOwner = null;
        item.LeaseExpiresAt = null;
        item.ErrorCode = interruptedUpload
            ? "LEASE_EXPIRED_UPLOAD_GRACE"
            : "LEASE_EXPIRED";
        item.ErrorMessage = interruptedUpload
            ? "Previous upload lease expired; retry was deferred to fence a late object write."
            : "Previous processing lease expired; item was returned to the queue.";
        item.StartedAt = null;
        item.CompletedAt = null;
        await context.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task<Guid?> TryClaimScanBatchAsync(
        FollowDbContext context,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var candidate = await context.MusicImportBatches
            .AsNoTracking()
            .Where(batch => batch.Status == MusicImportBatchStatus.Pending ||
                (batch.Status == MusicImportBatchStatus.Scanning &&
                 (batch.LeaseExpiresAt == null || batch.LeaseExpiresAt <= now)))
            .OrderBy(batch => batch.CreatedAt)
            .ThenBy(batch => batch.Id)
            .Select(batch => new { batch.Id, batch.Version })
            .FirstOrDefaultAsync(cancellationToken);
        if (candidate == null) return null;

        var leaseExpiresAt = now + _settings.LeaseDuration;
        if (context.Database.IsRelational())
        {
            var updated = await context.MusicImportBatches
                .Where(batch => batch.Id == candidate.Id &&
                    batch.Version == candidate.Version &&
                    (batch.Status == MusicImportBatchStatus.Pending ||
                     (batch.Status == MusicImportBatchStatus.Scanning &&
                      (batch.LeaseExpiresAt == null || batch.LeaseExpiresAt <= now))))
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(batch => batch.Status, MusicImportBatchStatus.Scanning)
                    .SetProperty(batch => batch.ScanStartedAt, batch => batch.ScanStartedAt ?? now)
                    .SetProperty(batch => batch.LeaseOwner, _workerId)
                    .SetProperty(batch => batch.LeaseExpiresAt, leaseExpiresAt)
                    .SetProperty(batch => batch.UpdatedAt, now)
                    .SetProperty(batch => batch.Version, batch => batch.Version + 1),
                    cancellationToken);
            return updated == 1 ? candidate.Id : null;
        }

        var tracked = await context.MusicImportBatches.SingleAsync(
            batch => batch.Id == candidate.Id,
            cancellationToken);
        if (tracked.Version != candidate.Version ||
            (tracked.Status != MusicImportBatchStatus.Pending &&
             (tracked.Status != MusicImportBatchStatus.Scanning || tracked.LeaseExpiresAt > now)))
            return null;

        if (tracked.Status == MusicImportBatchStatus.Pending)
            MusicImportStateMachine.EnsureTransition(
                tracked.Status,
                MusicImportBatchStatus.Scanning);
        tracked.Status = MusicImportBatchStatus.Scanning;
        tracked.ScanStartedAt ??= now;
        tracked.LeaseOwner = _workerId;
        tracked.LeaseExpiresAt = leaseExpiresAt;
        try
        {
            await context.SaveChangesAsync(cancellationToken);
            return tracked.Id;
        }
        catch (DbUpdateConcurrencyException)
        {
            return null;
        }
    }

    private async Task<bool> StartAutoReadyBatchAsync(
        FollowDbContext context,
        CancellationToken cancellationToken)
    {
        var batch = await context.MusicImportBatches
            .OrderBy(candidate => candidate.CreatedAt)
            .FirstOrDefaultAsync(candidate =>
                candidate.Status == MusicImportBatchStatus.Ready && candidate.AutoStart,
                cancellationToken);
        if (batch == null) return false;

        MusicImportStateMachine.EnsureTransition(batch.Status, MusicImportBatchStatus.Analyzing);
        batch.Status = MusicImportBatchStatus.Analyzing;
        batch.StartedAt ??= DateTime.UtcNow;
        await context.SaveChangesAsync(cancellationToken);
        return true;
    }

    private static async Task<bool> StartReadyToApplyBatchAsync(
        FollowDbContext context,
        CancellationToken cancellationToken)
    {
        var batch = await context.MusicImportBatches
            .OrderBy(candidate => candidate.CreatedAt)
            .ThenBy(candidate => candidate.Id)
            .FirstOrDefaultAsync(
                candidate => candidate.Status == MusicImportBatchStatus.ReadyToApply,
                cancellationToken);
        if (batch == null) return false;

        MusicImportStateMachine.EnsureTransition(
            batch.Status,
            MusicImportBatchStatus.Applying);
        batch.Status = MusicImportBatchStatus.Applying;
        await context.SaveChangesAsync(cancellationToken);
        return true;
    }

    private static async Task ReturnApplyFailureToReviewAsync(
        FollowDbContext context,
        Guid failedGroupId,
        ApplyFailure failure,
        CancellationToken cancellationToken)
    {
        context.ChangeTracker.Clear();
        var failedGroup = await context.MusicImportReviewGroups
            .Include(group => group.Batch)
                .ThenInclude(batch => batch.ReviewGroups)
            .SingleAsync(group => group.Id == failedGroupId, cancellationToken);
        var batch = failedGroup.Batch;
        if (batch.Status != MusicImportBatchStatus.Applying ||
            failedGroup.Status != MusicImportReviewStatus.Locked)
        {
            return;
        }

        foreach (var group in batch.ReviewGroups)
        {
            if (group.Id == failedGroupId)
            {
                group.Status = failure.RequiresNewDecision
                    ? MusicImportReviewStatus.Open
                    : MusicImportReviewStatus.Confirmed;
                group.ApplyErrorCode = failure.ErrorCode;
                group.ApplyErrorMessage = failure.Message;
            }
            else if (group.Status == MusicImportReviewStatus.Locked)
            {
                group.Status = MusicImportReviewStatus.Confirmed;
            }
        }

        MusicImportStateMachine.EnsureTransition(
            batch.Status,
            MusicImportBatchStatus.AwaitingReview);
        batch.Status = MusicImportBatchStatus.AwaitingReview;
        batch.LastErrorCode = failure.ErrorCode;
        batch.LastError = failure.Message;
        await context.SaveChangesAsync(cancellationToken);
    }

    private static ApplyFailure ClassifyApplyFailure(Exception exception)
    {
        if (exception is MusicImportApplyValidationException)
        {
            return new ApplyFailure(
                "APPLY_VALIDATION_FAILED",
                TruncateError(exception.Message),
                RequiresNewDecision: true);
        }
        if (exception is MusicImportApplyConflictException)
        {
            return new ApplyFailure(
                "APPLY_VERSION_CONFLICT",
                "The review group changed before it could be applied; review it again.",
                RequiresNewDecision: true);
        }
        if (exception is IOException or DbUpdateException)
        {
            return new ApplyFailure(
                "APPLY_IO_FAILED",
                "The selected audio could not be applied; confirm to retry.",
                RequiresNewDecision: false);
        }
        return new ApplyFailure(
            "APPLY_FAILED",
            "The selected audio could not be applied; review the decision and retry.",
            RequiresNewDecision: true);
    }

    private static string TruncateError(string message) =>
        message.Length <= 2048 ? message : message[..2048];

    private sealed record ApplyFailure(
        string ErrorCode,
        string Message,
        bool RequiresNewDecision);

    private static async Task<bool> CompleteApplyingBatchAsync(
        FollowDbContext context,
        CancellationToken cancellationToken)
    {
        var batch = await context.MusicImportBatches
            .OrderBy(candidate => candidate.CreatedAt)
            .ThenBy(candidate => candidate.Id)
            .FirstOrDefaultAsync(candidate =>
                candidate.Status == MusicImportBatchStatus.Applying &&
                candidate.ReviewGroups.Count > 0 &&
                candidate.ReviewGroups.All(group =>
                    group.Status == MusicImportReviewStatus.Applied),
                cancellationToken);
        if (batch == null) return false;

        MusicImportStateMachine.EnsureTransition(
            batch.Status,
            MusicImportBatchStatus.Verifying);
        batch.Status = MusicImportBatchStatus.Verifying;
        await context.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task<Guid?> TryClaimAnalysisItemAsync(
        FollowDbContext context,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var candidate = await context.MusicImportItems
            .AsNoTracking()
            .Where(item => item.Status == MusicImportItemStatus.Pending &&
                item.NextAttemptAt <= now &&
                item.Stage != MusicImportItemStage.Analyzed &&
                item.Stage != MusicImportItemStage.Grouped &&
                item.Stage != MusicImportItemStage.AwaitingReview &&
                item.Batch.Status == MusicImportBatchStatus.Analyzing)
            .OrderBy(item => item.NextAttemptAt)
            .ThenBy(item => item.CreatedAt)
            .ThenBy(item => item.Id)
            .Select(item => new { item.Id, item.Version })
            .FirstOrDefaultAsync(cancellationToken);
        if (candidate == null) return null;

        var leaseExpiresAt = now + _settings.LeaseDuration;
        if (context.Database.IsRelational())
        {
            var updated = await context.MusicImportItems
                .Where(item => item.Id == candidate.Id &&
                    item.Version == candidate.Version &&
                    item.Status == MusicImportItemStatus.Pending &&
                    item.NextAttemptAt <= now &&
                    item.Stage != MusicImportItemStage.Analyzed &&
                    item.Stage != MusicImportItemStage.Grouped &&
                    item.Stage != MusicImportItemStage.AwaitingReview &&
                    item.Batch.Status == MusicImportBatchStatus.Analyzing)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(item => item.Status, MusicImportItemStatus.Processing)
                    .SetProperty(item => item.AttemptCount, item => item.AttemptCount + 1)
                    .SetProperty(item => item.Retryable, false)
                    .SetProperty(item => item.LeaseOwner, _workerId)
                    .SetProperty(item => item.LeaseExpiresAt, leaseExpiresAt)
                    .SetProperty(item => item.ErrorCode, (string?)null)
                    .SetProperty(item => item.ErrorMessage, (string?)null)
                    .SetProperty(item => item.StartedAt, now)
                    .SetProperty(item => item.CompletedAt, (DateTime?)null)
                    .SetProperty(item => item.UpdatedAt, now)
                    .SetProperty(item => item.Version, item => item.Version + 1),
                    cancellationToken);
            return updated == 1 ? candidate.Id : null;
        }

        var tracked = await context.MusicImportItems
            .Include(item => item.Batch)
            .SingleAsync(item => item.Id == candidate.Id, cancellationToken);
        if (tracked.Version != candidate.Version ||
            tracked.Status != MusicImportItemStatus.Pending ||
            tracked.NextAttemptAt > now ||
            tracked.Stage is MusicImportItemStage.Analyzed or
                MusicImportItemStage.Grouped or
                MusicImportItemStage.AwaitingReview ||
            tracked.Batch.Status != MusicImportBatchStatus.Analyzing)
        {
            return null;
        }

        tracked.Status = MusicImportItemStatus.Processing;
        tracked.AttemptCount++;
        tracked.Retryable = false;
        tracked.LeaseOwner = _workerId;
        tracked.LeaseExpiresAt = leaseExpiresAt;
        tracked.ErrorCode = null;
        tracked.ErrorMessage = null;
        tracked.StartedAt = now;
        tracked.CompletedAt = null;
        try
        {
            await context.SaveChangesAsync(cancellationToken);
            return tracked.Id;
        }
        catch (DbUpdateConcurrencyException)
        {
            return null;
        }
    }

    private static async Task<bool> TryStartGroupingAsync(
        FollowDbContext context,
        CancellationToken cancellationToken)
    {
        var batch = await context.MusicImportBatches
            .OrderBy(candidate => candidate.CreatedAt)
            .ThenBy(candidate => candidate.Id)
            .FirstOrDefaultAsync(candidate =>
                candidate.Status == MusicImportBatchStatus.Analyzing &&
                !candidate.Items.Any(item =>
                    (item.Status == MusicImportItemStatus.Pending ||
                     item.Status == MusicImportItemStatus.Processing) &&
                    item.Stage != MusicImportItemStage.Analyzed &&
                    item.Stage != MusicImportItemStage.Grouped &&
                    item.Stage != MusicImportItemStage.AwaitingReview),
                cancellationToken);
        if (batch == null) return false;

        MusicImportStateMachine.EnsureTransition(
            batch.Status,
            MusicImportBatchStatus.Grouping);
        batch.Status = MusicImportBatchStatus.Grouping;
        await context.SaveChangesAsync(cancellationToken);
        return true;
    }


    private static async Task<bool> CompleteVerifyingBatchAsync(
        FollowDbContext context,
        CancellationToken cancellationToken)
    {
        var batch = await context.MusicImportBatches
            .OrderBy(candidate => candidate.CreatedAt)
            .FirstOrDefaultAsync(
                candidate => candidate.Status == MusicImportBatchStatus.Verifying,
                cancellationToken);
        if (batch == null) return false;

        var hasFailures = await context.MusicImportItems.AnyAsync(
            item => item.BatchId == batch.Id && item.Status == MusicImportItemStatus.Failed,
            cancellationToken);
        var terminalStatus = hasFailures
            ? MusicImportBatchStatus.CompletedWithErrors
            : MusicImportBatchStatus.Completed;
        MusicImportStateMachine.EnsureTransition(batch.Status, terminalStatus);
        batch.Status = terminalStatus;
        batch.CompletedAt = DateTime.UtcNow;
        await context.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task MarkScanFailedAsync(
        FollowDbContext context,
        Guid batchId,
        string errorCode,
        CancellationToken cancellationToken)
    {
        context.ChangeTracker.Clear();
        var now = DateTime.UtcNow;
        var batch = await context.MusicImportBatches.SingleOrDefaultAsync(
            candidate => candidate.Id == batchId &&
                candidate.Status == MusicImportBatchStatus.Scanning &&
                candidate.LeaseOwner == _workerId &&
                candidate.LeaseExpiresAt > now,
            cancellationToken);
        if (batch == null) return;

        MusicImportStateMachine.EnsureTransition(batch.Status, MusicImportBatchStatus.Failed);
        batch.Status = MusicImportBatchStatus.Failed;
        batch.LastErrorCode = errorCode;
        batch.LastError = "The source scan failed.";
        batch.CompletedAt = DateTime.UtcNow;
        batch.LeaseOwner = null;
        batch.LeaseExpiresAt = null;
        await context.SaveChangesAsync(cancellationToken);
    }
}
