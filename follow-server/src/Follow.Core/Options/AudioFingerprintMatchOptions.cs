namespace Follow.Core.Options;

public sealed record AudioFingerprintMatchOptions(
    double MatchThreshold,
    double MinimumOverlapFraction,
    TimeSpan MaximumDurationDifference,
    int MaximumAlignmentOffsetFrames);
