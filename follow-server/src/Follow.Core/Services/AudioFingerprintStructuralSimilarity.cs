using System.Numerics;
using Follow.Core.Models;
using Follow.Core.Options;

namespace Follow.Core.Services;

public static class AudioFingerprintStructuralSimilarity
{
    public static AudioFingerprintStructuralMatch Compare(
        AudioFingerprint left,
        AudioFingerprint right,
        AudioFingerprintStructuralOptions options)
    {
        ArgumentNullException.ThrowIfNull(left);
        ArgumentNullException.ThrowIfNull(right);
        ArgumentNullException.ThrowIfNull(options);
        ValidateOptions(options);

        var candidateMaximumOffset = left.Frames?.Count == right.Frames?.Count
            ? 0
            : options.MaximumCandidateAlignmentOffsetFrames;
        var candidate = AudioFingerprintSimilarity.Compare(
            left,
            right,
            new AudioFingerprintMatchOptions(
                options.CandidateSimilarityThreshold,
                0.3,
                TimeSpan.FromDays(1),
                candidateMaximumOffset));
        var measurement = Measure(left, right, options.SegmentCount, candidate);

        if (candidate.Disposition is AudioFingerprintMatchDisposition.Invalid or
            AudioFingerprintMatchDisposition.Incompatible)
        {
            return new AudioFingerprintStructuralMatch(candidate, measurement);
        }

        if (measurement.OverallSimilarity < options.CandidateSimilarityThreshold)
        {
            return Result(
                measurement,
                AudioFingerprintMatchDisposition.Different,
                "Overall fingerprint is below the candidate recall threshold.");
        }

        if (measurement.DurationDifference > options.MaximumDurationDifference)
        {
            return Result(
                measurement,
                AudioFingerprintMatchDisposition.Uncertain,
                "Candidate duration structure differs beyond the configured bound.");
        }

        if (measurement.CoverageFraction < options.MinimumCoverageFraction)
        {
            return Result(
                measurement,
                AudioFingerprintMatchDisposition.Uncertain,
                "Candidate fingerprint coverage is incomplete.");
        }

        if (Math.Abs(measurement.OffsetFrames) > options.MaximumAlignmentOffsetFrames)
        {
            return Result(
                measurement,
                AudioFingerprintMatchDisposition.Uncertain,
                "Candidate alignment offset changes the recording structure.");
        }

        var minimumSegment = measurement.SegmentSimilarities.Count == 0
            ? 0
            : measurement.SegmentSimilarities.Min();
        if (measurement.OverallSimilarity >= options.MatchSimilarityThreshold &&
            minimumSegment >= options.MinimumSegmentSimilarity)
        {
            return Result(
                measurement,
                AudioFingerprintMatchDisposition.Match,
                "Overall and segment fingerprints meet the calibrated structure thresholds.");
        }

        return Result(
            measurement,
            AudioFingerprintMatchDisposition.Different,
            "Candidate fingerprint does not preserve all segment structure.");
    }

    private static AudioFingerprintStructureMeasurement Measure(
        AudioFingerprint left,
        AudioFingerprint right,
        int segmentCount,
        AudioFingerprintMatch candidate)
    {
        var segmentScores = new double[segmentCount];
        for (var segment = 0; segment < segmentCount; segment++)
        {
            segmentScores[segment] = SegmentSimilarity(
                left.Frames,
                right.Frames,
                segment,
                segmentCount);
        }

        var maximumFrames = Math.Max(left.Frames?.Count ?? 0, right.Frames?.Count ?? 0);
        var coverage = maximumFrames == 0
            ? 0
            : candidate.OverlapFrames / (double)maximumFrames;

        return new AudioFingerprintStructureMeasurement(
            candidate.Similarity,
            segmentScores,
            coverage,
            candidate.OverlapFrames,
            candidate.OffsetFrames,
            (left.SourceDuration - right.SourceDuration).Duration());
    }

    private static double SegmentSimilarity(
        IReadOnlyList<uint>? left,
        IReadOnlyList<uint>? right,
        int segment,
        int segmentCount)
    {
        if (left == null || right == null || left.Count == 0 || right.Count == 0)
            return 0;

        var leftStart = left.Count * segment / segmentCount;
        var leftEnd = left.Count * (segment + 1) / segmentCount;
        var rightStart = right.Count * segment / segmentCount;
        var rightEnd = right.Count * (segment + 1) / segmentCount;
        var leftLength = leftEnd - leftStart;
        var rightLength = rightEnd - rightStart;
        var samples = Math.Min(leftLength, rightLength);
        if (samples <= 0)
            return 0;

        long differingBits = 0;
        for (var index = 0; index < samples; index++)
        {
            var leftIndex = leftStart + index * leftLength / samples;
            var rightIndex = rightStart + index * rightLength / samples;
            differingBits += BitOperations.PopCount(left[leftIndex] ^ right[rightIndex]);
        }

        return 1d - differingBits / (samples * 32d);
    }

    private static AudioFingerprintStructuralMatch Result(
        AudioFingerprintStructureMeasurement measurement,
        AudioFingerprintMatchDisposition disposition,
        string reason) =>
        new(
            new AudioFingerprintMatch(
                measurement.OverallSimilarity,
                measurement.OverlapFrames,
                measurement.OffsetFrames,
                disposition,
                reason),
            measurement);

    private static void ValidateOptions(AudioFingerprintStructuralOptions options)
    {
        if (options.CandidateSimilarityThreshold is < 0 or > 1 ||
            options.MatchSimilarityThreshold is < 0 or > 1 ||
            options.MinimumSegmentSimilarity is < 0 or > 1 ||
            options.MinimumCoverageFraction is <= 0 or > 1)
        {
            throw new ArgumentOutOfRangeException(nameof(options));
        }
        if (options.MatchSimilarityThreshold < options.CandidateSimilarityThreshold)
            throw new ArgumentException("Match threshold cannot be below candidate threshold.", nameof(options));
        if (options.MaximumDurationDifference < TimeSpan.Zero ||
            options.MaximumAlignmentOffsetFrames < 0 ||
            options.MaximumCandidateAlignmentOffsetFrames < options.MaximumAlignmentOffsetFrames ||
            options.SegmentCount < 2)
        {
            throw new ArgumentOutOfRangeException(nameof(options));
        }
    }
}
