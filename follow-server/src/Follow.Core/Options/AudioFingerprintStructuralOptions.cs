namespace Follow.Core.Options;

public sealed record AudioFingerprintStructuralOptions(
    double CandidateSimilarityThreshold,
    double MatchSimilarityThreshold,
    double MinimumSegmentSimilarity,
    double MinimumCoverageFraction,
    TimeSpan MaximumDurationDifference,
    int MaximumAlignmentOffsetFrames,
    int MaximumCandidateAlignmentOffsetFrames,
    int SegmentCount);
