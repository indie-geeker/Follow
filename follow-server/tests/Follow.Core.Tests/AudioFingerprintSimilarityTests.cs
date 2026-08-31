using Follow.Core.Models;
using Follow.Core.Options;
using Follow.Core.Services;

namespace Follow.Core.Tests;

public class AudioFingerprintSimilarityTests
{
    private static readonly AudioFingerprintMatchOptions Options = new(
        MatchThreshold: 0.95,
        MinimumOverlapFraction: 0.8,
        MaximumDurationDifference: TimeSpan.FromSeconds(2),
        MaximumAlignmentOffsetFrames: 2);

    [Fact]
    public void Compare_IdenticalFingerprintsScoreOneAndMatch()
    {
        var fingerprint = Fingerprint([1, 2, 3, 4]);

        var result = AudioFingerprintSimilarity.Compare(fingerprint, fingerprint, Options);

        Assert.Equal(1d, result.Similarity);
        Assert.Equal(AudioFingerprintMatchDisposition.Match, result.Disposition);
        Assert.Equal(4, result.OverlapFrames);
        Assert.Equal(0, result.OffsetFrames);
    }

    [Fact]
    public void Compare_NormalizesHammingDistanceAcrossOverlappingFrames()
    {
        var left = Fingerprint([0u, 0u]);
        var right = Fingerprint([0u, 1u]);

        var result = AudioFingerprintSimilarity.Compare(left, right, Options);

        Assert.Equal(1d - (1d / 64d), result.Similarity, precision: 12);
        Assert.Equal(AudioFingerprintMatchDisposition.Match, result.Disposition);
    }

    [Theory]
    [InlineData(1, "1.0", 2, "1.0")]
    [InlineData(2, "1.0", 2, "2.0")]
    public void Compare_RequiresCompatibleAlgorithmAndVersion(
        int leftAlgorithm,
        string leftVersion,
        int rightAlgorithm,
        string rightVersion)
    {
        var result = AudioFingerprintSimilarity.Compare(
            Fingerprint([1, 2, 3], leftAlgorithm, leftVersion),
            Fingerprint([1, 2, 3], rightAlgorithm, rightVersion),
            Options);

        Assert.Equal(AudioFingerprintMatchDisposition.Incompatible, result.Disposition);
        Assert.Contains("algorithm", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Compare_InsufficientOverlapIsUncertain()
    {
        var result = AudioFingerprintSimilarity.Compare(
            Fingerprint([1, 2, 3, 4]),
            Fingerprint([1, 2]),
            Options);

        Assert.Equal(AudioFingerprintMatchDisposition.Uncertain, result.Disposition);
        Assert.Contains("overlap", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Compare_DurationMismatchIsUncertain()
    {
        var result = AudioFingerprintSimilarity.Compare(
            Fingerprint([1, 2, 3], durationSeconds: 20),
            Fingerprint([1, 2, 3], durationSeconds: 30),
            Options);

        Assert.Equal(AudioFingerprintMatchDisposition.Uncertain, result.Disposition);
        Assert.Contains("duration", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Compare_FrameOffsetBeyondBoundIsUncertain()
    {
        var result = AudioFingerprintSimilarity.Compare(
            Fingerprint([8, 8, 1, 2, 3, 4, 5, 6]),
            Fingerprint([1, 2, 3, 4, 5]),
            Options);

        Assert.Equal(AudioFingerprintMatchDisposition.Uncertain, result.Disposition);
        Assert.Contains("offset", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Compare_FindsBestBoundedAlignment()
    {
        var result = AudioFingerprintSimilarity.Compare(
            Fingerprint([99, 1, 2, 3, 4]),
            Fingerprint([1, 2, 3, 4]),
            Options);

        Assert.Equal(1d, result.Similarity);
        Assert.Equal(AudioFingerprintMatchDisposition.Match, result.Disposition);
        Assert.Equal(1, Math.Abs(result.OffsetFrames));
    }

    [Fact]
    public void Compare_IsSymmetric()
    {
        var left = Fingerprint([99, 1, 2, 3, 4]);
        var right = Fingerprint([1, 2, 3, 4]);

        var forward = AudioFingerprintSimilarity.Compare(left, right, Options);
        var reverse = AudioFingerprintSimilarity.Compare(right, left, Options);

        Assert.Equal(forward.Similarity, reverse.Similarity);
        Assert.Equal(forward.OverlapFrames, reverse.OverlapFrames);
        Assert.Equal(forward.OffsetFrames, -reverse.OffsetFrames);
        Assert.Equal(forward.Disposition, reverse.Disposition);
    }

    [Fact]
    public void Compare_EmptyFingerprintFailsClosed()
    {
        var result = AudioFingerprintSimilarity.Compare(
            Fingerprint([]),
            Fingerprint([1, 2, 3]),
            Options);

        Assert.Equal(AudioFingerprintMatchDisposition.Invalid, result.Disposition);
        Assert.Equal(0d, result.Similarity);
        Assert.Contains("empty", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    private static AudioFingerprint Fingerprint(
        uint[] frames,
        int algorithm = 2,
        string version = "1.0",
        int durationSeconds = 20) =>
        new(algorithm, version, TimeSpan.FromSeconds(durationSeconds), frames);
}
