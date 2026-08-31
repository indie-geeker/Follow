using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Follow.Infrastructure.Services;

public sealed class MusicImportReviewService(FollowDbContext context)
    : IMusicImportReviewService
{
    public async Task<MusicImportReviewBatchDto?> GetBatchReviewAsync(
        Guid batchId,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        ValidatePage(page, pageSize);
        var batch = await context.MusicImportBatches
            .AsNoTracking()
            .SingleOrDefaultAsync(candidate => candidate.Id == batchId, cancellationToken);
        if (batch == null) return null;
        var statusCounts = await context.MusicImportReviewGroups
            .AsNoTracking()
            .Where(group => group.BatchId == batchId)
            .GroupBy(group => group.Status)
            .Select(group => new { Status = group.Key, Count = group.Count() })
            .ToDictionaryAsync(entry => entry.Status, entry => entry.Count, cancellationToken);
        var totalCount = statusCounts.Values.Sum();
        var groups = await GroupQuery(tracking: false)
            .Where(group => group.BatchId == batchId)
            .OrderBy(group => group.CreatedAt)
            .ThenBy(group => group.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        return new MusicImportReviewBatchDto(
            batch.Id,
            ContractName(batch.Status),
            batch.Version,
            new MusicImportReviewSummaryDto(
                Count(MusicImportReviewStatus.Open),
                Count(MusicImportReviewStatus.Confirmed),
                Count(MusicImportReviewStatus.Locked),
                Count(MusicImportReviewStatus.Applied),
                Count(MusicImportReviewStatus.Deferred),
                Count(MusicImportReviewStatus.Conflict),
                Count(MusicImportReviewStatus.Failed)),
            groups.Select(ToDto).ToArray(),
            totalCount,
            page,
            pageSize,
            TotalPages(totalCount, pageSize));

        int Count(MusicImportReviewStatus status) => statusCounts.GetValueOrDefault(status);
    }

    public async Task<MusicImportReviewGroupDto?> GetGroupAsync(
        Guid groupId,
        CancellationToken cancellationToken = default)
    {
        var group = await GroupQuery(tracking: false)
            .SingleOrDefaultAsync(candidate => candidate.Id == groupId, cancellationToken);
        return group == null ? null : ToDto(group);
    }

    public async Task<MusicImportReviewGroupDto> SaveDecisionAsync(
        Guid groupId,
        Guid actingUserId,
        MusicImportReviewDecisionRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (actingUserId == Guid.Empty)
            throw new ArgumentException("An acting administrator is required.", nameof(actingUserId));

        await using var transaction = await BeginTransactionIfRelationalAsync(cancellationToken);
        try
        {
            var group = await GroupQuery(tracking: true)
                .SingleOrDefaultAsync(candidate => candidate.Id == groupId, cancellationToken)
                ?? throw new KeyNotFoundException("Music import review group was not found.");
            if (group.Status is MusicImportReviewStatus.Locked or
                MusicImportReviewStatus.Applied or
                MusicImportReviewStatus.Conflict or
                MusicImportReviewStatus.Failed)
            {
                throw new InvalidOperationException("The review group is immutable in its current state.");
            }
            if (group.Version != request.ExpectedVersion)
                throw new MusicImportReviewConflictException(ToDto(group));
            if (!TryParseContractName(request.DecisionKind, out MusicImportDecisionKind kind))
                throw new ArgumentException("The review decision kind is invalid.", nameof(request));

            var selectedIds = request.SelectedItemIds?.Distinct().ToArray() ?? [];
            ValidateDecision(group, kind, selectedIds);
            ApplyDecision(group, kind, selectedIds, actingUserId);
            await context.SaveChangesAsync(cancellationToken);
            if (transaction != null) await transaction.CommitAsync(cancellationToken);
            return ToDto(group);
        }
        catch (DbUpdateConcurrencyException)
        {
            if (transaction != null) await transaction.RollbackAsync(CancellationToken.None);
            context.ChangeTracker.Clear();
            var current = await GetGroupAsync(groupId, CancellationToken.None)
                ?? throw new KeyNotFoundException("Music import review group was not found.");
            throw new MusicImportReviewConflictException(current);
        }
        catch
        {
            if (transaction != null) await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    public async Task<MusicImportReviewBatchStateDto> LockBatchAsync(
        Guid batchId,
        Guid actingUserId,
        MusicImportLockRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (actingUserId == Guid.Empty)
            throw new ArgumentException("An acting administrator is required.", nameof(actingUserId));

        await using var transaction = await BeginTransactionIfRelationalAsync(cancellationToken);
        try
        {
            var batch = await context.MusicImportBatches
                .Include(candidate => candidate.ReviewGroups)
                .SingleOrDefaultAsync(candidate => candidate.Id == batchId, cancellationToken)
                ?? throw new KeyNotFoundException("Music import batch was not found.");
            if (batch.Status != MusicImportBatchStatus.AwaitingReview)
                throw new InvalidOperationException("Batch must be awaiting review.");

            var supplied = request.Groups?.ToArray() ?? [];
            if (supplied.Length != batch.ReviewGroups.Count ||
                supplied.Select(item => item.GroupId).Distinct().Count() != supplied.Length ||
                batch.ReviewGroups.Any(group => supplied.All(item => item.GroupId != group.Id)))
            {
                throw new ArgumentException(
                    "The apply confirmation must include every advertised review group exactly once.",
                    nameof(request));
            }
            if (!MusicImportStateMachine.CanPrepareForApply(batch.ReviewGroups.ToArray()))
                throw new InvalidOperationException("Every review group must be explicitly confirmed.");

            foreach (var group in batch.ReviewGroups)
            {
                var expected = supplied.Single(item => item.GroupId == group.Id).ExpectedVersion;
                if (group.Version != expected)
                {
                    context.ChangeTracker.Clear();
                    var current = await GetGroupAsync(group.Id, cancellationToken)
                        ?? throw new KeyNotFoundException("Music import review group was not found.");
                    throw new MusicImportReviewConflictException(current);
                }
                if (group.Status == MusicImportReviewStatus.Confirmed)
                {
                    group.Status = MusicImportReviewStatus.Locked;
                    group.ApplyErrorCode = null;
                    group.ApplyErrorMessage = null;
                }
            }

            MusicImportStateMachine.EnsureTransition(
                batch.Status,
                MusicImportBatchStatus.ReadyToApply);
            batch.Status = MusicImportBatchStatus.ReadyToApply;
            await context.SaveChangesAsync(cancellationToken);
            if (transaction != null) await transaction.CommitAsync(cancellationToken);
            return new MusicImportReviewBatchStateDto(
                batch.Id,
                ContractName(batch.Status),
                batch.Version);
        }
        catch
        {
            if (transaction != null) await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    private IQueryable<MusicImportReviewGroup> GroupQuery(bool tracking)
    {
        IQueryable<MusicImportReviewGroup> query = context.MusicImportReviewGroups
            .Include(group => group.Items)
            .Include(group => group.ExistingTrack)
            .Include(group => group.AudioRevisions)
                .ThenInclude(revision => revision.StorageDeletionJob);
        return tracking ? query : query.AsNoTracking();
    }

    private static void ValidateDecision(
        MusicImportReviewGroup group,
        MusicImportDecisionKind kind,
        Guid[] selectedIds)
    {
        if (selectedIds.Length == 0)
            throw new ArgumentException("Every decision requires explicit candidate IDs.");
        var itemIds = group.Items.Select(item => item.Id).ToHashSet();
        if (selectedIds.Any(id => !itemIds.Contains(id)))
            throw new ArgumentException("A selected candidate does not belong to this review group.");
        if (kind == MusicImportDecisionKind.TreatAsSeparateRecording &&
            group.MatchKind == MusicImportMatchKind.ExactSha256)
        {
            throw new ArgumentException(
                "Byte-identical candidates cannot be treated as separate recordings.");
        }

        var requiresExisting = kind is
            MusicImportDecisionKind.ReplaceExistingTrack or
            MusicImportDecisionKind.KeepExistingTrack or
            MusicImportDecisionKind.RejectDuplicate;
        if (requiresExisting && group.ExistingTrackId == null)
            throw new ArgumentException("This decision requires a matched existing Track.");

        if (kind is MusicImportDecisionKind.CreateTrack or
            MusicImportDecisionKind.ReplaceExistingTrack)
        {
            if (selectedIds.Length != 1)
                throw new ArgumentException("This decision requires exactly one selected candidate.");
            return;
        }

        if (selectedIds.Length != itemIds.Count || itemIds.Any(id => !selectedIds.Contains(id)))
            throw new ArgumentException("This decision must explicitly include every candidate.");
    }

    private static void ApplyDecision(
        MusicImportReviewGroup group,
        MusicImportDecisionKind kind,
        IReadOnlyCollection<Guid> selectedIds,
        Guid actingUserId)
    {
        foreach (var item in group.Items)
        {
            var selected = selectedIds.Contains(item.Id);
            item.Decision = kind switch
            {
                MusicImportDecisionKind.CreateTrack when selected => MusicImportDecisionKind.CreateTrack,
                MusicImportDecisionKind.ReplaceExistingTrack when selected => MusicImportDecisionKind.ReplaceExistingTrack,
                MusicImportDecisionKind.CreateTrack or MusicImportDecisionKind.ReplaceExistingTrack =>
                    MusicImportDecisionKind.RejectDuplicate,
                _ => kind
            };
            item.DecisionTrackId = kind is
                MusicImportDecisionKind.ReplaceExistingTrack or
                MusicImportDecisionKind.KeepExistingTrack or
                MusicImportDecisionKind.RejectDuplicate
                    ? group.ExistingTrackId
                    : null;
            item.Stage = MusicImportItemStage.AwaitingReview;
        }
        group.Status = kind == MusicImportDecisionKind.Defer
            ? MusicImportReviewStatus.Deferred
            : MusicImportReviewStatus.Confirmed;
        group.ConfirmedByUserId = actingUserId;
        group.ConfirmedAt = DateTime.UtcNow;
        group.ApplyErrorCode = null;
        group.ApplyErrorMessage = null;
    }

    private async Task<IDbContextTransaction?> BeginTransactionIfRelationalAsync(
        CancellationToken cancellationToken) =>
        context.Database.IsRelational()
            ? await context.Database.BeginTransactionAsync(cancellationToken)
            : null;

    private static MusicImportReviewGroupDto ToDto(MusicImportReviewGroup group)
    {
        var decision = ResolveDecision(group.Items);
        var selectedIds = decision is MusicImportDecisionKind.CreateTrack or
            MusicImportDecisionKind.ReplaceExistingTrack
                ? group.Items
                    .Where(item => item.Decision == decision)
                    .Select(item => item.Id)
                    .Order()
                    .ToArray()
                : decision.HasValue
                    ? group.Items.Select(item => item.Id).Order().ToArray()
                    : [];
        var cleanup = group.AudioRevisions
            .OrderByDescending(revision => revision.CreatedAt)
            .ThenByDescending(revision => revision.Id)
            .FirstOrDefault();
        var cleanupFailed = cleanup?.CleanupStatus == TrackAudioRevisionCleanupStatus.Failed;

        return new MusicImportReviewGroupDto(
            group.Id,
            group.BatchId,
            ContractName(group.Status),
            ContractName(group.MatchKind),
            MatchExplanation(group),
            group.Version,
            group.ExistingTrackId,
            group.ExistingTrack == null ? null : new MusicImportExistingTrackDto(
                group.ExistingTrack.Id,
                group.ExistingTrack.Title,
                group.ExistingTrack.OriginalFileName,
                group.ExistingTrack.Codec,
                group.ExistingTrack.Container,
                group.ExistingTrack.IsLossless,
                group.ExistingTrack.SampleRateHz,
                group.ExistingTrack.BitDepth,
                group.ExistingTrack.Channels,
                group.ExistingTrack.BitRateKbps,
                group.ExistingTrack.FileSizeBytes,
                group.ExistingTrack.ExactDurationMilliseconds),
            group.RecommendedItemId,
            group.RecommendationExplanation,
            group.FingerprintVersion,
            group.FingerprintAlgorithm,
            group.OverallSimilarity,
            group.MinimumSegmentSimilarity,
            group.CoverageFraction,
            group.AlignmentOffsetFrames,
            group.ConfirmedByUserId,
            group.ConfirmedAt,
            decision.HasValue ? ContractName(decision.Value) : null,
            selectedIds,
            group.ApplyErrorCode,
            group.ApplyErrorMessage,
            cleanup == null ? null : ContractName(cleanup.CleanupStatus),
            cleanupFailed ? "STORAGE_CLEANUP_FAILED" : null,
            cleanupFailed ? cleanup?.StorageDeletionJob?.LastError : null,
            group.Items
                .OrderBy(item => item.RelativePath)
                .ThenBy(item => item.Id)
                .Select(item =>
                {
                    var previewAvailable =
                        item.SourceKind == MusicImportSourceKind.MountedDirectory ||
                        !string.IsNullOrWhiteSpace(item.SourceReference);
                    return new MusicImportReviewCandidateDto(
                        item.Id,
                        item.Version,
                        item.RelativePath,
                        item.SourceKind == MusicImportSourceKind.BrowserStaging
                            ? $"browser-upload/{item.OriginalFileName}"
                            : item.RelativePath,
                        item.OriginalFileName,
                        ContractName(item.SourceKind),
                        item.ExtractedTitle,
                        item.ExtractedArtist,
                        item.ExtractedAlbum,
                        item.Codec,
                        item.Container,
                        item.IsLossless,
                        item.SampleRateHz,
                        item.BitDepth,
                        item.Channels,
                        item.BitRateKbps,
                        item.SizeBytes,
                        item.ExactDurationMilliseconds,
                        item.Decision.HasValue ? ContractName(item.Decision.Value) : null,
                        item.DecisionTrackId,
                        previewAvailable,
                        previewAvailable
                            ? $"/api/admin/music-imports/items/{item.Id}/preview"
                            : null);
                })
                .ToArray());
    }

    private static MusicImportDecisionKind? ResolveDecision(
        IEnumerable<MusicImportItem> items)
    {
        var decisions = items
            .Where(item => item.Decision.HasValue)
            .Select(item => item.Decision!.Value)
            .Distinct()
            .ToArray();
        if (decisions.Contains(MusicImportDecisionKind.CreateTrack))
            return MusicImportDecisionKind.CreateTrack;
        if (decisions.Contains(MusicImportDecisionKind.ReplaceExistingTrack))
            return MusicImportDecisionKind.ReplaceExistingTrack;
        return decisions.Length == 1 ? decisions[0] : null;
    }

    private static string MatchExplanation(MusicImportReviewGroup group) =>
        group.MatchKind switch
        {
            MusicImportMatchKind.ExactSha256 => "文件内容 SHA-256 完全一致",
            MusicImportMatchKind.AcousticFingerprint when group.OverallSimilarity.HasValue =>
                $"声学指纹相似度 {group.OverallSimilarity.Value:P1}",
            MusicImportMatchKind.AcousticFingerprint => "声学指纹相似",
            MusicImportMatchKind.UserSeparated => "管理员已确认作为不同录音处理",
            _ => "未发现确定的重复匹配"
        };

    private static void ValidatePage(int page, int pageSize)
    {
        if (page < 1) throw new ArgumentOutOfRangeException(nameof(page));
        if (pageSize is < 1 or > 100) throw new ArgumentOutOfRangeException(nameof(pageSize));
    }

    private static int TotalPages(int totalCount, int pageSize) =>
        totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)pageSize);

    private static bool TryParseContractName<TEnum>(string value, out TEnum parsed)
        where TEnum : struct, Enum
    {
        parsed = default;
        return !string.IsNullOrWhiteSpace(value) &&
            !int.TryParse(value, out _) &&
            Enum.TryParse(value, ignoreCase: true, out parsed) &&
            Enum.IsDefined(parsed);
    }

    private static string ContractName<TEnum>(TEnum value)
        where TEnum : struct, Enum
    {
        var name = value.ToString();
        return name.Length == 0 ? name : char.ToLowerInvariant(name[0]) + name[1..];
    }
}
