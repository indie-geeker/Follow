namespace Follow.Core.Models;

public sealed record AudioFingerprintStructureMeasurement(
    double OverallSimilarity,
    IReadOnlyList<double> SegmentSimilarities,
    double CoverageFraction,
    int OverlapFrames,
    int OffsetFrames,
    TimeSpan DurationDifference);

public sealed record AudioFingerprintStructuralMatch(
    AudioFingerprintMatch Match,
    AudioFingerprintStructureMeasurement Measurement);
