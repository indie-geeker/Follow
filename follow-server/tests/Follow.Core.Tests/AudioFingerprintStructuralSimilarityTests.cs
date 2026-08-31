using Follow.Core.Models;
using Follow.Core.Options;
using Follow.Core.Services;

namespace Follow.Core.Tests;

public class AudioFingerprintStructuralSimilarityTests
{
    private static readonly AudioFingerprintStructuralOptions Options = new(
        CandidateSimilarityThreshold: 0.85,
        MatchSimilarityThreshold: 0.99,
        MinimumSegmentSimilarity: 0.98,
        MinimumCoverageFraction: 0.85,
        MaximumDurationDifference: TimeSpan.FromSeconds(2),
        MaximumAlignmentOffsetFrames: 2,
        MaximumCandidateAlignmentOffsetFrames: 32,
        SegmentCount: 3);

    [Fact]
    public void Compare_IdenticalFingerprintMatchesAllThreeSegments()
    {
        var fingerprint = Fingerprint([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);

        var result = AudioFingerprintStructuralSimilarity.Compare(
            fingerprint,
            fingerprint,
            Options);

        Assert.Equal(AudioFingerprintMatchDisposition.Match, result.Match.Disposition);
        Assert.Equal(1d, result.Measurement.OverallSimilarity);
        Assert.Equal([1d, 1d, 1d], result.Measurement.SegmentSimilarities);
        Assert.Equal(1d, result.Measurement.CoverageFraction);
        Assert.Equal(12, result.Match.OverlapFrames);
    }

    [Fact]
    public void Compare_HighOverallScoreWithAddedIntroIsUncertain()
    {
        var original = Fingerprint([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], durationSeconds: 20);
        var withIntro = Fingerprint([99, 98, 97, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], durationSeconds: 23);

        var result = AudioFingerprintStructuralSimilarity.Compare(original, withIntro, Options);

        Assert.Equal(1d, result.Measurement.OverallSimilarity);
        Assert.Equal(AudioFingerprintMatchDisposition.Uncertain, result.Match.Disposition);
        Assert.Contains("duration", result.Match.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Compare_HighScoreWithClippedCoverageIsUncertain()
    {
        var original = Fingerprint([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], durationSeconds: 20);
        var clipped = Fingerprint([3, 4, 5, 6, 7, 8, 9, 10], durationSeconds: 14);

        var result = AudioFingerprintStructuralSimilarity.Compare(original, clipped, Options);

        Assert.True(result.Measurement.OverallSimilarity >= 0.99);
        Assert.True(result.Measurement.CoverageFraction < Options.MinimumCoverageFraction);
        Assert.Equal(AudioFingerprintMatchDisposition.Uncertain, result.Match.Disposition);
    }

    [Fact]
    public void Compare_SameLengthButChangedSegmentStructureIsDifferent()
    {
        var original = Fingerprint([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        var changed = Fingerprint([0, 0, 0, 0, 15, 15, 15, 15, 0, 0, 0, 0]);

        var result = AudioFingerprintStructuralSimilarity.Compare(original, changed, Options);

        Assert.Equal(AudioFingerprintMatchDisposition.Different, result.Match.Disposition);
        Assert.True(result.Measurement.SegmentSimilarities.Min() < Options.MinimumSegmentSimilarity);
    }

    [Fact]
    public void Compare_UnrelatedFingerprintIsDifferentBeforeStructuralApproval()
    {
        var result = AudioFingerprintStructuralSimilarity.Compare(
            Fingerprint([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
            Fingerprint([uint.MaxValue, uint.MaxValue, uint.MaxValue, uint.MaxValue,
                uint.MaxValue, uint.MaxValue, uint.MaxValue, uint.MaxValue,
                uint.MaxValue, uint.MaxValue, uint.MaxValue, uint.MaxValue]),
            Options);

        Assert.Equal(AudioFingerprintMatchDisposition.Different, result.Match.Disposition);
        Assert.Contains("candidate", result.Match.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Compare_IncompatibleFingerprintsFailClosed()
    {
        var result = AudioFingerprintStructuralSimilarity.Compare(
            Fingerprint([1, 2, 3, 4]),
            Fingerprint([1, 2, 3, 4], algorithm: 1),
            Options);

        Assert.Equal(AudioFingerprintMatchDisposition.Incompatible, result.Match.Disposition);
    }

    private static AudioFingerprint Fingerprint(
        uint[] frames,
        int durationSeconds = 20,
        int algorithm = 2) =>
        new(algorithm, "1.6.1", TimeSpan.FromSeconds(durationSeconds), frames);
}
