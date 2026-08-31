using Follow.Core.Options;

namespace Follow.Infrastructure.Options;

public sealed class AudioFingerprintOptions
{
    public const string SectionName = "AudioFingerprint";

    public string ExecutablePath { get; set; } = "fpcalc";
    public int Algorithm { get; set; } = 2;
    public int MaximumLengthSeconds { get; set; } = 120;
    public int TimeoutSeconds { get; set; } = 30;
    public TimeSpan Timeout { get; set; }
    public int MaximumStandardOutputBytes { get; set; } = 2 * 1024 * 1024;
    public int MaximumStandardErrorBytes { get; set; } = 16 * 1024;
    public long MaximumSourceBytes { get; set; } = 2L * 1024 * 1024 * 1024;
    public string TemporaryDirectory { get; set; } = string.Empty;
    public string RequiredVersionPrefix { get; set; } = "1.6.";
    public double CandidateSimilarityThreshold { get; set; } = 0.85;
    public double MatchSimilarityThreshold { get; set; } = 0.99;
    public double MinimumSegmentSimilarity { get; set; } = 0.98;
    public double MinimumCoverageFraction { get; set; } = 0.85;
    public int MaximumDurationDifferenceSeconds { get; set; } = 2;
    public int MaximumAlignmentOffsetFrames { get; set; } = 2;
    public int MaximumCandidateAlignmentOffsetFrames { get; set; } = 512;
    public int SegmentCount { get; set; } = 3;

    public TimeSpan EffectiveTimeout =>
        Timeout > TimeSpan.Zero ? Timeout : TimeSpan.FromSeconds(TimeoutSeconds);

    public AudioFingerprintStructuralOptions ToStructuralOptions() =>
        new(
            CandidateSimilarityThreshold,
            MatchSimilarityThreshold,
            MinimumSegmentSimilarity,
            MinimumCoverageFraction,
            TimeSpan.FromSeconds(MaximumDurationDifferenceSeconds),
            MaximumAlignmentOffsetFrames,
            MaximumCandidateAlignmentOffsetFrames,
            SegmentCount);
}
