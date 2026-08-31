using System.Globalization;
using Follow.Core.Models;

namespace Follow.Core.Services;

public static class MusicImportQualityRecommendation
{
    public static MusicImportRecommendation Recommend(
        IReadOnlyCollection<MusicImportRecommendationCandidate> candidates)
    {
        ArgumentNullException.ThrowIfNull(candidates);
        if (candidates.Count == 0)
            throw new ArgumentException("At least one candidate is required.", nameof(candidates));

        var ordered = candidates
            .OrderBy(candidate => candidate, CandidateComparer.Instance)
            .ToArray();
        var preferred = ordered[0];
        var runnerUp = ordered.Length > 1 ? ordered[1] : null;
        var explanation = BuildExplanation(preferred, runnerUp);

        return new MusicImportRecommendation(
            preferred.CandidateId,
            explanation,
            [Describe(preferred.Quality)]);
    }

    private static string BuildExplanation(
        MusicImportRecommendationCandidate preferred,
        MusicImportRecommendationCandidate? runnerUp)
    {
        var preferredDescription = Describe(preferred.Quality);
        if (runnerUp == null)
            return $"Recommendation only: {preferredDescription}.";

        var runnerDescription = Describe(runnerUp.Quality);
        var reason = CompareQuality(preferred.Quality, runnerUp.Quality) != 0
            ? $"higher quality than {runnerDescription}"
            : preferred.MetadataCompleteness != runnerUp.MetadataCompleteness
                ? "more complete metadata"
                : preferred.SourceStability != runnerUp.SourceStability
                    ? "more stable source"
                    : "stable path tie-breaker";

        return $"{preferredDescription}; {reason}.";
    }

    private static string Describe(AudioQualityFacts quality)
    {
        var codec = (quality.Codec ?? quality.Container)?.ToUpperInvariant();
        if (quality.IsLossless == true)
        {
            var facts = new List<string>();
            if (quality.BitDepth is int bitDepth)
                facts.Add($"{bitDepth}-bit");
            if (quality.SampleRateHz is int sampleRate)
                facts.Add($"{FormatKilohertz(sampleRate)} kHz");
            var qualityDescription = facts.Count == 0
                ? "lossless quality"
                : string.Join(" / ", facts);
            return codec == null ? qualityDescription : $"{qualityDescription} {codec}";
        }

        if (quality.IsLossless == false)
        {
            var bitrate = quality.BitRateKbps is int bitRate
                ? $"{bitRate} kbps"
                : "bitrate unknown";
            return codec == null ? bitrate : $"{bitrate} {codec}";
        }

        return codec == null ? "quality unknown" : $"quality unknown {codec}";
    }

    private static string FormatKilohertz(int sampleRateHz) =>
        (sampleRateHz / 1000d).ToString("0.###", CultureInfo.InvariantCulture);

    private static int CompareQuality(AudioQualityFacts left, AudioQualityFacts right)
    {
        var kindComparison = QualityKind(right).CompareTo(QualityKind(left));
        if (kindComparison != 0)
            return kindComparison;

        if (left.IsLossless == true)
        {
            var bitDepth = NullableValue(right.BitDepth).CompareTo(NullableValue(left.BitDepth));
            if (bitDepth != 0)
                return bitDepth;
            return NullableValue(right.SampleRateHz).CompareTo(NullableValue(left.SampleRateHz));
        }

        if (left.IsLossless == false)
            return NullableValue(right.BitRateKbps).CompareTo(NullableValue(left.BitRateKbps));

        return 0;
    }

    private static int QualityKind(AudioQualityFacts quality) => quality.IsLossless switch
    {
        true => 2,
        false => 1,
        null => 0
    };

    private static int NullableValue(int? value) => value ?? int.MinValue;

    private sealed class CandidateComparer : IComparer<MusicImportRecommendationCandidate>
    {
        public static CandidateComparer Instance { get; } = new();

        public int Compare(
            MusicImportRecommendationCandidate? left,
            MusicImportRecommendationCandidate? right)
        {
            if (ReferenceEquals(left, right))
                return 0;
            if (left == null)
                return 1;
            if (right == null)
                return -1;

            var quality = CompareQuality(left.Quality, right.Quality);
            if (quality != 0)
                return quality;

            var metadata = right.MetadataCompleteness.CompareTo(left.MetadataCompleteness);
            if (metadata != 0)
                return metadata;

            var stability = right.SourceStability.CompareTo(left.SourceStability);
            if (stability != 0)
                return stability;

            var path = string.Compare(
                left.RelativePath,
                right.RelativePath,
                StringComparison.Ordinal);
            return path != 0 ? path : left.CandidateId.CompareTo(right.CandidateId);
        }
    }
}
