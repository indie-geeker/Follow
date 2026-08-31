using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Follow.Infrastructure.Services;

public sealed class MusicImportService : IMusicImportService
{
    internal const string BatchRequestUniqueConstraintName =
        "UX_MusicImportBatches_RequestedByUser_ClientRequestId";

    private readonly FollowDbContext _context;
    private readonly MusicImportRuntimeSettings _settings;
    private readonly IStorageService? _storage;
    private readonly AudioFingerprintCapabilityState? _fingerprintCapability;

    public MusicImportService(
        FollowDbContext context,
        MusicImportRuntimeSettings settings,
        IStorageService? storage = null,
        AudioFingerprintCapabilityState? fingerprintCapability = null)
    {
        _context = context;
        _settings = settings;
        _storage = storage;
        _fingerprintCapability = fingerprintCapability;
    }

    public async Task<MusicImportUploadAcceptedDto> CreateBrowserUploadAsync(
        Guid requestedByUserId,
        BrowserMusicImportUpload upload,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        ArgumentNullException.ThrowIfNull(upload);
        ArgumentNullException.ThrowIfNull(upload.Content);
        if (!upload.Content.CanRead)
            throw new ArgumentException("Browser upload stream must be readable.", nameof(upload));

        var clientRequestId = upload.ClientRequestId?.Trim();
        if (string.IsNullOrEmpty(clientRequestId) || clientRequestId.Length > 64)
            throw new ArgumentException("Client request ID must contain 1 to 64 characters.", nameof(upload));
        var originalFileName = NormalizeBrowserFileName(upload.FileName);
        AudioFilePolicy.ValidateCandidate(
            originalFileName,
            upload.Length,
            _settings.MaximumFileBytes,
            _settings.MaximumRelativePathLength);
        if (!AudioFilePolicy.TryGetCanonicalContentType(originalFileName, out var contentType))
            throw new ArgumentException("Unsupported audio format.", nameof(upload));

        var existing = await _context.MusicImportBatches
            .AsNoTracking()
            .SingleOrDefaultAsync(batch =>
                batch.RequestedByUserId == requestedByUserId &&
                batch.ClientRequestId == clientRequestId,
                cancellationToken);
        if (existing != null)
        {
            if (existing.SourceKind != MusicImportSourceKind.BrowserStaging)
                throw new InvalidOperationException("The idempotency key belongs to another source type.");
            var existingItem = await _context.MusicImportItems
                .AsNoTracking()
                .SingleAsync(item => item.BatchId == existing.Id, cancellationToken);
            if (existingItem.SizeBytes != upload.Length ||
                !string.Equals(existingItem.OriginalFileName, originalFileName, StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    "The idempotency key already belongs to a different upload payload.");
            }
            return new MusicImportUploadAcceptedDto(
                existing.Id,
                existingItem.Id,
                ContractName(existing.Status));
        }

        var storage = _storage
            ?? throw new InvalidOperationException("Browser staging storage is unavailable.");
        var now = DateTime.UtcNow;
        var itemId = Guid.NewGuid();
        var extension = Path.GetExtension(originalFileName).ToLowerInvariant();
        var objectPath = ImportObjectPath.BuildStaging(itemId, extension);
        var writeAttempted = false;
        try
        {
            writeAttempted = true;
            await storage.WriteObjectAsync(
                objectPath,
                upload.Content,
                upload.Length,
                contentType,
                cancellationToken);
            var stored = await storage.GetObjectMetadataAsync(objectPath, cancellationToken);
            if (stored == null ||
                stored.Length != upload.Length ||
                string.IsNullOrWhiteSpace(stored.ETag))
            {
                throw new IOException("The staged browser object could not be verified.");
            }

            var batch = new MusicImportBatch
            {
                SourceKind = MusicImportSourceKind.BrowserStaging,
                RequestedByUserId = requestedByUserId,
                ClientRequestId = clientRequestId,
                RelativeDirectory = string.Empty,
                AutoStart = true,
                Status = MusicImportBatchStatus.Analyzing,
                DiscoveredFileCount = 1,
                TotalBytes = upload.Length,
                ScanStartedAt = now,
                ScanCompletedAt = now,
                StartedAt = now
            };
            var item = new MusicImportItem
            {
                Id = itemId,
                Batch = batch,
                BatchId = batch.Id,
                SourceKind = MusicImportSourceKind.BrowserStaging,
                SourceReference = objectPath,
                StagingObjectPath = objectPath,
                SourceETag = stored.ETag,
                RelativePath = $"browser/{itemId:N}/{originalFileName}",
                OriginalFileName = originalFileName,
                Extension = extension,
                SizeBytes = upload.Length,
                SourceModifiedAt = MusicImportScanner.NormalizeDatabaseTimestamp(now),
                Status = MusicImportItemStatus.Pending,
                Stage = MusicImportItemStage.None
            };
            _context.MusicImportBatches.Add(batch);
            _context.MusicImportItems.Add(item);
            await _context.SaveChangesAsync(cancellationToken);

            return new MusicImportUploadAcceptedDto(
                batch.Id,
                item.Id,
                ContractName(batch.Status));
        }
        catch
        {
            if (writeAttempted)
            {
                try
                {
                    await storage.DeleteFileAsync(objectPath);
                }
                catch
                {
                    // Preserve the ingestion failure. Durable orphan reconciliation is handled separately.
                }
            }
            throw;
        }
    }

    public async Task<MusicImportBatchDto> CreateBatchAsync(
        Guid requestedByUserId,
        CreateMusicImportRequest request,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        ArgumentNullException.ThrowIfNull(request);

        var clientRequestId = request.ClientRequestId?.Trim();
        if (string.IsNullOrEmpty(clientRequestId) || clientRequestId.Length > 64)
            throw new ArgumentException("Client request ID must contain 1 to 64 characters.", nameof(request));

        var relativeDirectory = MusicImportPathPolicy.Resolve(
            _settings.SourceRoot,
            request.RelativeDirectory ?? string.Empty,
            _settings.MaximumRelativePathLength).RelativePath;
        var existing = await LoadBatchByRequestAsync(
            requestedByUserId,
            clientRequestId,
            cancellationToken);
        if (existing != null)
        {
            EnsureMatchingPayload(existing, relativeDirectory, request.AutoStart);
            return ToDto(existing, await LoadProgressAsync(existing.Id, cancellationToken));
        }

        var batch = new MusicImportBatch
        {
            RequestedByUserId = requestedByUserId,
            ClientRequestId = clientRequestId,
            RelativeDirectory = relativeDirectory,
            AutoStart = request.AutoStart
        };
        _context.MusicImportBatches.Add(batch);
        try
        {
            await _context.SaveChangesAsync(cancellationToken);
            return ToDto(batch, EmptyProgress);
        }
        catch (DbUpdateException exception) when (IsBatchRequestUniqueViolation(exception))
        {
            _context.ChangeTracker.Clear();
            var winner = await LoadBatchByRequestAsync(
                requestedByUserId,
                clientRequestId,
                cancellationToken);
            if (winner == null) throw;
            EnsureMatchingPayload(winner, relativeDirectory, request.AutoStart);
            return ToDto(winner, await LoadProgressAsync(winner.Id, cancellationToken));
        }
    }

    public async Task<MusicImportBatchPageDto> GetBatchesAsync(
        int page = 1,
        int pageSize = 20,
        MusicImportBatchStatus? status = null,
        CancellationToken cancellationToken = default)
    {
        ValidatePage(page, pageSize);
        var query = _context.MusicImportBatches.AsQueryable();
        if (status.HasValue) query = query.Where(batch => batch.Status == status.Value);

        var totalCount = await query.CountAsync(cancellationToken);
        var batches = await query
            .AsNoTracking()
            .OrderByDescending(batch => batch.CreatedAt)
            .ThenByDescending(batch => batch.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        var progress = await LoadProgressAsync(
            batches.Select(batch => batch.Id),
            cancellationToken);
        return new MusicImportBatchPageDto(
            batches.Select(batch => ToDto(
                batch,
                progress.GetValueOrDefault(batch.Id, EmptyProgress))).ToArray(),
            totalCount,
            page,
            pageSize,
            TotalPages(totalCount, pageSize));
    }

    public async Task<MusicImportBatchDto?> GetBatchAsync(
        Guid batchId,
        CancellationToken cancellationToken = default)
    {
        var batch = await _context.MusicImportBatches
            .AsNoTracking()
            .SingleOrDefaultAsync(candidate => candidate.Id == batchId, cancellationToken);
        return batch == null
            ? null
            : ToDto(batch, await LoadProgressAsync(batch.Id, cancellationToken));
    }

    public async Task<MusicImportItemPageDto?> GetItemsAsync(
        Guid batchId,
        int page = 1,
        int pageSize = 50,
        MusicImportItemStatus? status = null,
        CancellationToken cancellationToken = default)
    {
        ValidatePage(page, pageSize);
        if (!await _context.MusicImportBatches.AnyAsync(
                batch => batch.Id == batchId,
                cancellationToken))
            return null;

        var query = _context.MusicImportItems.Where(item => item.BatchId == batchId);
        if (status.HasValue) query = query.Where(item => item.Status == status.Value);

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderBy(item => item.RelativePath)
            .ThenBy(item => item.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        return new MusicImportItemPageDto(
            items.Select(ToDto).ToArray(),
            totalCount,
            page,
            pageSize,
            TotalPages(totalCount, pageSize));
    }

    public Task<MusicImportBatchDto?> StartAsync(
        Guid batchId,
        CancellationToken cancellationToken = default) =>
        TransitionAsync(
            batchId,
            MusicImportBatchStatus.Ready,
            MusicImportBatchStatus.Analyzing,
            batch =>
            {
                batch.StartedAt ??= DateTime.UtcNow;
                batch.CompletedAt = null;
            },
            cancellationToken);

    public Task<MusicImportBatchDto?> PauseAsync(
        Guid batchId,
        CancellationToken cancellationToken = default) =>
        TransitionAsync(
            batchId,
            MusicImportBatchStatus.Analyzing,
            MusicImportBatchStatus.PauseRequested,
            null,
            cancellationToken);

    public Task<MusicImportBatchDto?> ResumeAsync(
        Guid batchId,
        CancellationToken cancellationToken = default) =>
        TransitionAsync(
            batchId,
            MusicImportBatchStatus.Paused,
            MusicImportBatchStatus.Analyzing,
            null,
            cancellationToken);

    public async Task<MusicImportBatchDto?> CancelAsync(
        Guid batchId,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        var batch = await LoadBatchAsync(batchId, cancellationToken);
        if (batch == null) return null;
        if (batch.Status == MusicImportBatchStatus.CancelRequested)
            return ToDto(batch, await LoadProgressAsync(batch.Id, cancellationToken));

        MusicImportStateMachine.EnsureTransition(
            batch.Status,
            MusicImportBatchStatus.CancelRequested);
        batch.Status = MusicImportBatchStatus.CancelRequested;
        batch.CancelRequestedAt = DateTime.UtcNow;
        await SaveControlChangesAsync(cancellationToken);
        return ToDto(batch, await LoadProgressAsync(batch.Id, cancellationToken));
    }

    public async Task<MusicImportBatchDto?> RetryFailuresAsync(
        Guid batchId,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        var batch = await LoadBatchAsync(batchId, cancellationToken);
        if (batch == null) return null;

        MusicImportStateMachine.EnsureTransition(
            batch.Status,
            MusicImportBatchStatus.Ready);
        var now = DateTime.UtcNow;
        if (_context.Database.IsRelational())
        {
            await using var transaction = await _context.Database
                .BeginTransactionAsync(cancellationToken);
            try
            {
                var updated = await _context.MusicImportItems
                    .Where(item => item.BatchId == batch.Id &&
                        item.Status == MusicImportItemStatus.Failed &&
                        item.Retryable)
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(item => item.Status, MusicImportItemStatus.Pending)
                        .SetProperty(item => item.Stage, MusicImportItemStage.None)
                        .SetProperty(item => item.Retryable, false)
                        .SetProperty(item => item.NextAttemptAt, now)
                        .SetProperty(item => item.LeaseOwner, (string?)null)
                        .SetProperty(item => item.LeaseExpiresAt, (DateTime?)null)
                        .SetProperty(item => item.ErrorCode, (string?)null)
                        .SetProperty(item => item.ErrorMessage, (string?)null)
                        .SetProperty(item => item.StartedAt, (DateTime?)null)
                        .SetProperty(item => item.CompletedAt, (DateTime?)null)
                        .SetProperty(item => item.UpdatedAt, now)
                        .SetProperty(item => item.Version, item => item.Version + 1),
                        cancellationToken);
                if (updated == 0)
                    throw new InvalidOperationException("The batch has no retryable failures.");

                ResetBatchForRetry(batch);
                await SaveControlChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
            }
            catch
            {
                await transaction.RollbackAsync(CancellationToken.None);
                throw;
            }
        }
        else
        {
            var retryableItems = await _context.MusicImportItems
                .Where(item => item.BatchId == batch.Id &&
                    item.Status == MusicImportItemStatus.Failed &&
                    item.Retryable)
                .ToArrayAsync(cancellationToken);
            if (retryableItems.Length == 0)
                throw new InvalidOperationException("The batch has no retryable failures.");

            foreach (var item in retryableItems)
            {
                item.Status = MusicImportItemStatus.Pending;
                item.Stage = MusicImportItemStage.None;
                item.Retryable = false;
                item.NextAttemptAt = now;
                item.LeaseOwner = null;
                item.LeaseExpiresAt = null;
                item.ErrorCode = null;
                item.ErrorMessage = null;
                item.StartedAt = null;
                item.CompletedAt = null;
            }

            ResetBatchForRetry(batch);
            await SaveControlChangesAsync(cancellationToken);
        }

        _context.ChangeTracker.Clear();
        return ToDto(batch, await LoadProgressAsync(batch.Id, cancellationToken));
    }

    private async Task<MusicImportBatchDto?> TransitionAsync(
        Guid batchId,
        MusicImportBatchStatus requiredStatus,
        MusicImportBatchStatus nextStatus,
        Action<MusicImportBatch>? mutate,
        CancellationToken cancellationToken)
    {
        EnsureEnabled();
        var batch = await LoadBatchAsync(batchId, cancellationToken);
        if (batch == null) return null;
        if (batch.Status != requiredStatus)
            throw new InvalidOperationException($"Batch must be {ContractName(requiredStatus)}.");

        MusicImportStateMachine.EnsureTransition(batch.Status, nextStatus);
        batch.Status = nextStatus;
        mutate?.Invoke(batch);
        await SaveControlChangesAsync(cancellationToken);
        return ToDto(batch, await LoadProgressAsync(batch.Id, cancellationToken));
    }

    private async Task SaveControlChangesAsync(CancellationToken cancellationToken)
    {
        try
        {
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException exception)
        {
            _context.ChangeTracker.Clear();
            throw new InvalidOperationException(
                "The music import batch changed concurrently; refresh and retry the operation.",
                exception);
        }
    }

    private static void ResetBatchForRetry(MusicImportBatch batch)
    {
        batch.Status = MusicImportBatchStatus.Ready;
        batch.CompletedAt = null;
        batch.LastErrorCode = null;
        batch.LastError = null;
    }

    private Task<MusicImportBatch?> LoadBatchAsync(
        Guid batchId,
        CancellationToken cancellationToken) =>
        _context.MusicImportBatches
            .SingleOrDefaultAsync(batch => batch.Id == batchId, cancellationToken);

    private Task<MusicImportBatch?> LoadBatchByRequestAsync(
        Guid requestedByUserId,
        string clientRequestId,
        CancellationToken cancellationToken) =>
        _context.MusicImportBatches
            .SingleOrDefaultAsync(
                batch => batch.RequestedByUserId == requestedByUserId &&
                    batch.ClientRequestId == clientRequestId,
                cancellationToken);

    private static MusicImportBatchDto ToDto(
        MusicImportBatch batch,
        MusicImportProgressDto progress)
    {
        return new MusicImportBatchDto(
            batch.Id,
            batch.RequestedByUserId,
            batch.ClientRequestId,
            batch.RelativeDirectory,
            ContractName(batch.SourceKind),
            batch.AutoStart,
            ContractName(batch.Status),
            batch.DiscoveredFileCount,
            batch.IgnoredFileCount,
            batch.TotalBytes,
            progress,
            batch.LastErrorCode,
            batch.LastError,
            batch.CreatedAt,
            batch.UpdatedAt,
            batch.ScanStartedAt,
            batch.ScanCompletedAt,
            batch.StartedAt,
            batch.CompletedAt);
    }

    private async Task<MusicImportProgressDto> LoadProgressAsync(
        Guid batchId,
        CancellationToken cancellationToken)
    {
        var progress = await LoadProgressAsync([batchId], cancellationToken);
        return progress.GetValueOrDefault(batchId, EmptyProgress);
    }

    private async Task<Dictionary<Guid, MusicImportProgressDto>> LoadProgressAsync(
        IEnumerable<Guid> batchIds,
        CancellationToken cancellationToken)
    {
        var ids = batchIds.Distinct().ToArray();
        if (ids.Length == 0) return [];

        var aggregates = await _context.MusicImportItems
            .AsNoTracking()
            .Where(item => ids.Contains(item.BatchId))
            .GroupBy(item => item.BatchId)
            .Select(group => new ProgressAggregate(
                group.Key,
                group.Count(item => item.Status == MusicImportItemStatus.Pending),
                group.Count(item => item.Status == MusicImportItemStatus.Processing),
                group.Count(item => item.Status == MusicImportItemStatus.Imported),
                group.Count(item => item.Status == MusicImportItemStatus.Duplicate),
                group.Count(item => item.Status == MusicImportItemStatus.Skipped),
                group.Count(item => item.Status == MusicImportItemStatus.Failed),
                group.Count(item => item.Status == MusicImportItemStatus.Failed && item.Retryable),
                group.Count(item => item.Status == MusicImportItemStatus.Cancelled),
                group.Count(item => item.Stage == MusicImportItemStage.SourceValidation),
                group.Count(item => item.Stage == MusicImportItemStage.Hashing),
                group.Count(item => item.Stage == MusicImportItemStage.Metadata),
                group.Count(item => item.Stage == MusicImportItemStage.Fingerprinting),
                group.Count(item => item.Stage == MusicImportItemStage.Analyzed),
                group.Count(item => item.Stage == MusicImportItemStage.Grouped),
                group.Count(item => item.Stage == MusicImportItemStage.AwaitingReview),
                group.Count(item => item.Stage == MusicImportItemStage.Applying),
                group.Count(item => item.Stage == MusicImportItemStage.Verified),
                group.Where(item => item.Status == MusicImportItemStatus.Imported ||
                        item.Status == MusicImportItemStatus.Duplicate ||
                        item.Status == MusicImportItemStatus.Skipped ||
                        item.Status == MusicImportItemStatus.Failed ||
                        item.Status == MusicImportItemStatus.Cancelled)
                    .Sum(item => (long?)item.SizeBytes) ?? 0))
            .ToListAsync(cancellationToken);

        return aggregates.ToDictionary(
            aggregate => aggregate.BatchId,
            aggregate => new MusicImportProgressDto(
                aggregate.Pending,
                aggregate.Processing,
                aggregate.Imported,
                aggregate.Duplicate,
                aggregate.Skipped,
                aggregate.Failed,
                aggregate.RetryableFailed,
                aggregate.Cancelled,
                aggregate.ProcessedBytes,
                new MusicImportPhaseProgressDto(
                    aggregate.SourceValidation,
                    aggregate.Hashing,
                    aggregate.Metadata,
                    aggregate.Fingerprinting,
                    aggregate.Analyzed,
                    aggregate.Grouped,
                    aggregate.AwaitingReview,
                    aggregate.Applying,
                    aggregate.Verified)));
    }

    private static MusicImportItemDto ToDto(MusicImportItem item) => new(
        item.Id,
        item.RelativePath,
        item.OriginalFileName,
        item.SizeBytes,
        item.SourceModifiedAt,
        ContractName(item.Status),
        ContractName(item.Stage),
        item.AttemptCount,
        item.Retryable,
        item.TrackId,
        item.ErrorCode,
        item.ErrorMessage,
        item.CreatedAt,
        item.UpdatedAt,
        item.StartedAt,
        item.CompletedAt);

    private static string ContractName<TEnum>(TEnum value)
        where TEnum : struct, Enum
    {
        var name = value.ToString();
        return name.Length == 0
            ? name
            : char.ToLowerInvariant(name[0]) + name[1..];
    }

    private void EnsureEnabled()
    {
        if (!_settings.Enabled)
            throw new InvalidOperationException("Music library import is disabled.");
        if (_fingerprintCapability != null &&
            !_fingerprintCapability.CanIngest(_settings.Enabled))
        {
            var code = _fingerprintCapability.Current.ErrorCode ?? "FINGERPRINT_UNAVAILABLE";
            throw new InvalidOperationException(
                $"Acoustic fingerprint analysis is unavailable ({code}); ingestion is disabled.");
        }
    }

    private static void ValidatePage(int page, int pageSize)
    {
        if (page < 1) throw new ArgumentOutOfRangeException(nameof(page));
        if (pageSize is < 1 or > 200) throw new ArgumentOutOfRangeException(nameof(pageSize));
    }

    private static int TotalPages(int totalCount, int pageSize) =>
        totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)pageSize);

    private static string NormalizeBrowserFileName(string fileName)
    {
        var normalized = MinioStorageService.NormalizeFileName(fileName);
        if (normalized.Length > 512)
            throw new ArgumentException("Browser upload file name is too long.", nameof(fileName));
        return normalized;
    }

    internal static bool IsBatchRequestUniqueViolation(DbUpdateException exception) =>
        exception.InnerException is PostgresException
        {
            SqlState: PostgresErrorCodes.UniqueViolation,
            ConstraintName: BatchRequestUniqueConstraintName
        };

    private static void EnsureMatchingPayload(
        MusicImportBatch batch,
        string relativeDirectory,
        bool autoStart)
    {
        if (!string.Equals(
                batch.RelativeDirectory,
                relativeDirectory,
                StringComparison.Ordinal) ||
            batch.AutoStart != autoStart)
        {
            throw new InvalidOperationException(
                "The idempotency key already belongs to a different request payload.");
        }
    }

    private static readonly MusicImportProgressDto EmptyProgress = new(
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        new MusicImportPhaseProgressDto(0, 0, 0, 0, 0, 0, 0, 0, 0));

    private sealed record ProgressAggregate(
        Guid BatchId,
        int Pending,
        int Processing,
        int Imported,
        int Duplicate,
        int Skipped,
        int Failed,
        int RetryableFailed,
        int Cancelled,
        int SourceValidation,
        int Hashing,
        int Metadata,
        int Fingerprinting,
        int Analyzed,
        int Grouped,
        int AwaitingReview,
        int Applying,
        int Verified,
        long ProcessedBytes);
}
