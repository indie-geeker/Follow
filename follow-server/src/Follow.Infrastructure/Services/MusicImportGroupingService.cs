using Follow.Core.Entities;
using Follow.Core.Models;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Options;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Creates review candidates only. It never persists a decision, Track, or media object.
/// </summary>
public sealed class MusicImportGroupingService
{
    private const int CandidatePageSize = 200;
    private readonly FollowDbContext _context;
    private readonly AudioFingerprintOptions _options;

    public MusicImportGroupingService(
        FollowDbContext context,
        IOptions<AudioFingerprintOptions> options)
    {
        _context = context;
        _options = options.Value;
    }

    public async Task GroupBatchAsync(
        Guid batchId,
        CancellationToken cancellationToken = default)
    {
        var batch = await _context.MusicImportBatches
            .SingleOrDefaultAsync(candidate => candidate.Id == batchId, cancellationToken)
            ?? throw new KeyNotFoundException("Music import batch was not found.");
        if (batch.Status == MusicImportBatchStatus.AwaitingReview)
            return;
        if (batch.Status != MusicImportBatchStatus.Grouping)
            throw new InvalidOperationException("Batch must be in the grouping phase.");

        var unfinished = await _context.MusicImportItems.AnyAsync(
            item => item.BatchId == batchId &&
                (item.Status == MusicImportItemStatus.Pending ||
                 item.Status == MusicImportItemStatus.Processing) &&
                item.Stage != MusicImportItemStage.Analyzed &&
                item.Stage != MusicImportItemStage.Grouped &&
                item.Stage != MusicImportItemStage.AwaitingReview,
            cancellationToken);
        if (unfinished)
            throw new InvalidOperationException("Every eligible item must finish analysis before grouping.");

        while (true)
        {
            var anchor = await _context.MusicImportItems
                .Where(item => item.BatchId == batchId &&
                    item.Status != MusicImportItemStatus.Failed &&
                    item.Stage == MusicImportItemStage.Analyzed &&
                    item.ReviewGroupId == null)
                .OrderBy(item => item.RelativePath)
                .ThenBy(item => item.Id)
                .FirstOrDefaultAsync(cancellationToken);
            if (anchor == null) break;
            await CreateGroupAsync(batch, anchor, cancellationToken);
        }

        MusicImportStateMachine.EnsureTransition(
            batch.Status,
            MusicImportBatchStatus.AwaitingReview);
        batch.Status = MusicImportBatchStatus.AwaitingReview;
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task CreateGroupAsync(
        MusicImportBatch batch,
        MusicImportItem anchor,
        CancellationToken cancellationToken)
    {
        var members = new List<MusicImportItem> { anchor };
        Track? existingTrack = null;
        var matchKind = MusicImportMatchKind.None;
        AudioFingerprintStructuralMatch? structuralMatch = null;

        if (anchor.ContentSha256 is { Length: 32 } hash)
        {
            existingTrack = await _context.Tracks
                .AsNoTracking()
                .OrderBy(track => track.CreatedAt)
                .FirstOrDefaultAsync(track => track.ContentSha256 != null &&
                    track.ContentSha256.SequenceEqual(hash), cancellationToken);
            var exactMemberCount = 0;
            while (true)
            {
                var exactPage = await _context.MusicImportItems
                    .Where(item => item.BatchId == batch.Id &&
                        item.Id != anchor.Id &&
                        item.ReviewGroupId == null &&
                        item.Stage == MusicImportItemStage.Analyzed &&
                        item.ContentSha256 != null &&
                        item.ContentSha256.SequenceEqual(hash))
                    .OrderBy(item => item.RelativePath)
                    .ThenBy(item => item.Id)
                    .Skip(exactMemberCount)
                    .Take(CandidatePageSize)
                    .ToListAsync(cancellationToken);
                members.AddRange(exactPage);
                exactMemberCount += exactPage.Count;
                if (exactPage.Count < CandidatePageSize) break;
            }
            if (existingTrack != null || exactMemberCount > 0)
                matchKind = MusicImportMatchKind.ExactSha256;
        }

        if (matchKind == MusicImportMatchKind.None && TryReadFingerprint(anchor, out var anchorFingerprint))
        {
            var trackOffset = 0;
            while (existingTrack == null)
            {
                var compatibleTracks = await _context.Tracks
                    .AsNoTracking()
                    .Where(track => track.FingerprintVersion == anchor.FingerprintVersion &&
                        track.FingerprintAlgorithm == anchor.FingerprintAlgorithm &&
                        track.FingerprintPayload != null &&
                        track.FingerprintFrameCount != null &&
                        track.FingerprintDurationMilliseconds != null)
                    .OrderBy(track => track.CreatedAt)
                    .ThenBy(track => track.Id)
                    .Skip(trackOffset)
                    .Take(CandidatePageSize)
                    .ToListAsync(cancellationToken);
                foreach (var track in compatibleTracks)
                {
                    if (!TryReadFingerprint(track, out var trackFingerprint)) continue;
                    var compared = AudioFingerprintStructuralSimilarity.Compare(
                        anchorFingerprint,
                        trackFingerprint,
                        _options.ToStructuralOptions());
                    if (compared.Match.Disposition != AudioFingerprintMatchDisposition.Match) continue;
                    existingTrack = track;
                    structuralMatch = compared;
                    matchKind = MusicImportMatchKind.AcousticFingerprint;
                    break;
                }
                trackOffset += compatibleTracks.Count;
                if (compatibleTracks.Count < CandidatePageSize) break;
            }

            var itemOffset = 0;
            while (true)
            {
                var compatibleItems = await _context.MusicImportItems
                    .Where(item => item.BatchId == batch.Id &&
                        item.Id != anchor.Id &&
                        item.ReviewGroupId == null &&
                        item.Stage == MusicImportItemStage.Analyzed &&
                        item.FingerprintVersion == anchor.FingerprintVersion &&
                        item.FingerprintAlgorithm == anchor.FingerprintAlgorithm &&
                        item.FingerprintPayload != null &&
                        item.FingerprintFrameCount != null &&
                        item.FingerprintDurationMilliseconds != null)
                    .OrderBy(item => item.RelativePath)
                    .ThenBy(item => item.Id)
                    .Skip(itemOffset)
                    .Take(CandidatePageSize)
                    .ToListAsync(cancellationToken);
                foreach (var candidate in compatibleItems)
                {
                    if (!TryReadFingerprint(candidate, out var candidateFingerprint)) continue;
                    var compared = AudioFingerprintStructuralSimilarity.Compare(
                        anchorFingerprint,
                        candidateFingerprint,
                        _options.ToStructuralOptions());
                    if (compared.Match.Disposition != AudioFingerprintMatchDisposition.Match) continue;
                    members.Add(candidate);
                    structuralMatch ??= compared;
                    matchKind = MusicImportMatchKind.AcousticFingerprint;
                }
                itemOffset += compatibleItems.Count;
                if (compatibleItems.Count < CandidatePageSize) break;
            }
        }

        var group = new MusicImportReviewGroup
        {
            Batch = batch,
            BatchId = batch.Id,
            Status = MusicImportReviewStatus.Open,
            MatchKind = matchKind,
            ExistingTrackId = existingTrack?.Id,
            FingerprintVersion = anchor.FingerprintVersion,
            FingerprintAlgorithm = anchor.FingerprintAlgorithm,
            OverallSimilarity = structuralMatch?.Measurement.OverallSimilarity,
            MinimumSegmentSimilarity = structuralMatch?.Measurement.SegmentSimilarities.Min(),
            CoverageFraction = structuralMatch?.Measurement.CoverageFraction,
            AlignmentOffsetFrames = structuralMatch?.Measurement.OffsetFrames
        };
        _context.MusicImportReviewGroups.Add(group);
        await _context.SaveChangesAsync(cancellationToken);

        foreach (var member in members)
        {
            member.ReviewGroupId = group.Id;
            member.Stage = MusicImportItemStage.Grouped;
        }
        var recommendation = MusicImportQualityRecommendation.Recommend(
            members.Select(ToRecommendationCandidate).ToArray());
        group.RecommendedItemId = recommendation.CandidateId;
        group.RecommendationExplanation = recommendation.Explanation;
        await _context.SaveChangesAsync(cancellationToken);
    }

    private static MusicImportRecommendationCandidate ToRecommendationCandidate(
        MusicImportItem item) => new(
        item.Id,
        item.RelativePath,
        new AudioQualityFacts(
            item.Codec,
            item.Container,
            item.IsLossless,
            item.SampleRateHz,
            item.BitDepth,
            item.Channels,
            item.BitRateKbps,
            item.SizeBytes),
        MetadataCompleteness(item),
        item.SourceKind == MusicImportSourceKind.MountedDirectory ? 2 : 1);

    private static int MetadataCompleteness(MusicImportItem item) =>
        (string.IsNullOrWhiteSpace(item.ExtractedTitle) ? 0 : 1) +
        (string.IsNullOrWhiteSpace(item.ExtractedArtist) ? 0 : 1) +
        (string.IsNullOrWhiteSpace(item.ExtractedAlbum) ? 0 : 1);

    private static bool TryReadFingerprint(
        MusicImportItem item,
        out AudioFingerprint fingerprint) =>
        TryReadFingerprint(
            item.FingerprintAlgorithm,
            item.FingerprintVersion,
            item.FingerprintPayload,
            item.FingerprintFrameCount,
            item.FingerprintDurationMilliseconds,
            out fingerprint);

    private static bool TryReadFingerprint(
        Track track,
        out AudioFingerprint fingerprint) =>
        TryReadFingerprint(
            track.FingerprintAlgorithm,
            track.FingerprintVersion,
            track.FingerprintPayload,
            track.FingerprintFrameCount,
            track.FingerprintDurationMilliseconds,
            out fingerprint);

    private static bool TryReadFingerprint(
        int? algorithm,
        string? version,
        byte[]? payload,
        int? frameCount,
        long? durationMilliseconds,
        out AudioFingerprint fingerprint)
    {
        if (algorithm == null ||
            string.IsNullOrWhiteSpace(version) ||
            payload == null ||
            frameCount == null ||
            durationMilliseconds == null)
        {
            fingerprint = null!;
            return false;
        }
        fingerprint = new AudioFingerprint(
            algorithm.Value,
            version,
            TimeSpan.FromMilliseconds(durationMilliseconds.Value),
            AudioFingerprintPayloadCodec.Decode(payload, frameCount.Value));
        return true;
    }
}
