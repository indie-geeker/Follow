using System.Numerics;
using Follow.Core.Models;
using Follow.Core.Options;

namespace Follow.Core.Services;

public static class AudioFingerprintSimilarity
{
    public static AudioFingerprintMatch Compare(
        AudioFingerprint left,
        AudioFingerprint right,
        AudioFingerprintMatchOptions options)
    {
        ArgumentNullException.ThrowIfNull(left);
        ArgumentNullException.ThrowIfNull(right);
        ArgumentNullException.ThrowIfNull(options);
        ValidateOptions(options);

        if (left.Frames == null || right.Frames == null ||
            left.Frames.Count == 0 || right.Frames.Count == 0)
        {
            return Result(AudioFingerprintMatchDisposition.Invalid, "Fingerprint frames are empty.");
        }

        if (left.Algorithm != right.Algorithm ||
            !string.Equals(left.Version, right.Version, StringComparison.Ordinal))
        {
            return Result(
                AudioFingerprintMatchDisposition.Incompatible,
                "Fingerprint algorithm or version is incompatible.");
        }

        if ((left.SourceDuration - right.SourceDuration).Duration() >
            options.MaximumDurationDifference)
        {
            return Result(
                AudioFingerprintMatchDisposition.Uncertain,
                "Source duration difference exceeds the configured bound.");
        }

        if (Math.Abs(left.Frames.Count - right.Frames.Count) >
            options.MaximumAlignmentOffsetFrames)
        {
            return Result(
                AudioFingerprintMatchDisposition.Uncertain,
                "Fingerprint frame offset exceeds the configured bound.");
        }

        var minimumOverlap = (int)Math.Ceiling(
            Math.Max(left.Frames.Count, right.Frames.Count) *
            options.MinimumOverlapFraction);
        var best = FindBestAlignment(
            left.Frames,
            right.Frames,
            options.MaximumAlignmentOffsetFrames,
            minimumOverlap);
        if (best.OverlapFrames < minimumOverlap)
        {
            return new AudioFingerprintMatch(
                best.Similarity,
                best.OverlapFrames,
                best.OffsetFrames,
                AudioFingerprintMatchDisposition.Uncertain,
                "Fingerprint overlap is below the configured minimum.");
        }

        var disposition = best.Similarity >= options.MatchThreshold
            ? AudioFingerprintMatchDisposition.Match
            : AudioFingerprintMatchDisposition.Different;
        var reason = disposition == AudioFingerprintMatchDisposition.Match
            ? "Fingerprint similarity meets the calibrated threshold."
            : "Fingerprint similarity is below the calibrated threshold.";

        return new AudioFingerprintMatch(
            best.Similarity,
            best.OverlapFrames,
            best.OffsetFrames,
            disposition,
            reason);
    }

    private static Alignment FindBestAlignment(
        IReadOnlyList<uint> left,
        IReadOnlyList<uint> right,
        int maximumOffset,
        int minimumOverlap)
    {
        Alignment? best = null;
        for (var offset = -maximumOffset; offset <= maximumOffset; offset++)
        {
            var leftStart = Math.Max(offset, 0);
            var rightStart = Math.Max(-offset, 0);
            var overlap = Math.Min(left.Count - leftStart, right.Count - rightStart);
            if (overlap < minimumOverlap)
                continue;

            long differingBits = 0;
            for (var index = 0; index < overlap; index++)
            {
                differingBits += BitOperations.PopCount(
                    left[leftStart + index] ^ right[rightStart + index]);
            }

            var similarity = 1d - (differingBits / (overlap * 32d));
            var candidate = new Alignment(similarity, overlap, offset);
            if (best == null || IsBetter(candidate, best))
                best = candidate;
        }

        return best ?? new Alignment(0, 0, 0);
    }

    private static bool IsBetter(Alignment candidate, Alignment current)
    {
        var similarity = candidate.Similarity.CompareTo(current.Similarity);
        if (similarity != 0)
            return similarity > 0;
        if (candidate.OverlapFrames != current.OverlapFrames)
            return candidate.OverlapFrames > current.OverlapFrames;
        return Math.Abs(candidate.OffsetFrames) < Math.Abs(current.OffsetFrames);
    }

    private static AudioFingerprintMatch Result(
        AudioFingerprintMatchDisposition disposition,
        string reason) =>
        new(0, 0, 0, disposition, reason);

    private static void ValidateOptions(AudioFingerprintMatchOptions options)
    {
        if (options.MatchThreshold is < 0 or > 1)
            throw new ArgumentOutOfRangeException(nameof(options.MatchThreshold));
        if (options.MinimumOverlapFraction is <= 0 or > 1)
            throw new ArgumentOutOfRangeException(nameof(options.MinimumOverlapFraction));
        if (options.MaximumDurationDifference < TimeSpan.Zero)
            throw new ArgumentOutOfRangeException(nameof(options.MaximumDurationDifference));
        if (options.MaximumAlignmentOffsetFrames < 0)
            throw new ArgumentOutOfRangeException(nameof(options.MaximumAlignmentOffsetFrames));
    }

    private sealed record Alignment(
        double Similarity,
        int OverlapFrames,
        int OffsetFrames);
}
