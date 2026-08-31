using Follow.Core.Models;
using Follow.Core.Services;
using Follow.Core.Entities;

namespace Follow.Core.Tests;

public class MusicImportQualityRecommendationTests
{
    [Fact]
    public void Recommend_PrefersLosslessAndExplainsComparedFacts()
    {
        var flacId = Guid.NewGuid();
        var mp3Id = Guid.NewGuid();
        var result = MusicImportQualityRecommendation.Recommend([
            Candidate(
                mp3Id,
                "disc/song.mp3",
                new AudioQualityFacts("mp3", "mp3", false, 44_100, null, 2, 320, 8_000_000)),
            Candidate(
                flacId,
                "disc/song.flac",
                new AudioQualityFacts("flac", "flac", true, 96_000, 24, 2, 2_800, 40_000_000))
        ]);

        Assert.Equal(flacId, result.CandidateId);
        Assert.Contains("24-bit / 96 kHz FLAC", result.Explanation);
        Assert.Contains("320 kbps MP3", result.Explanation);
    }

    [Fact]
    public void Recommend_UsesBitDepthThenSampleRateWithinLosslessCandidates()
    {
        var preferredId = Guid.NewGuid();
        var result = MusicImportQualityRecommendation.Recommend([
            Candidate(Guid.NewGuid(), "song-16.flac", Lossless(16, 192_000)),
            Candidate(preferredId, "song-24.flac", Lossless(24, 48_000))
        ]);

        Assert.Equal(preferredId, result.CandidateId);
        Assert.Contains("24-bit", result.Explanation);
    }

    [Fact]
    public void Recommend_UsesBitrateWithinLossyCandidates()
    {
        var preferredId = Guid.NewGuid();
        var result = MusicImportQualityRecommendation.Recommend([
            Candidate(Guid.NewGuid(), "song-128.mp3", Lossy(128)),
            Candidate(preferredId, "song-320.mp3", Lossy(320))
        ]);

        Assert.Equal(preferredId, result.CandidateId);
        Assert.Contains("320 kbps", result.Explanation);
    }

    [Fact]
    public void Recommend_UsesMetadataCompletenessThenSourceStability()
    {
        var completeId = Guid.NewGuid();
        var stableId = Guid.NewGuid();
        var quality = Lossy(320);

        var metadataWinner = MusicImportQualityRecommendation.Recommend([
            Candidate(Guid.NewGuid(), "a.mp3", quality, metadataCompleteness: 1, sourceStability: 2),
            Candidate(completeId, "b.mp3", quality, metadataCompleteness: 4, sourceStability: 1)
        ]);
        var stabilityWinner = MusicImportQualityRecommendation.Recommend([
            Candidate(Guid.NewGuid(), "c.mp3", quality, metadataCompleteness: 4, sourceStability: 1),
            Candidate(stableId, "d.mp3", quality, metadataCompleteness: 4, sourceStability: 2)
        ]);

        Assert.Equal(completeId, metadataWinner.CandidateId);
        Assert.Contains("more complete metadata", metadataWinner.Explanation);
        Assert.Equal(stableId, stabilityWinner.CandidateId);
        Assert.Contains("more stable source", stabilityWinner.Explanation);
    }

    [Fact]
    public void Recommend_UsesOrdinalRelativePathAsFinalStableTieBreaker()
    {
        var firstId = Guid.NewGuid();
        var quality = Lossy(320);

        var result = MusicImportQualityRecommendation.Recommend([
            Candidate(Guid.NewGuid(), "z/song.mp3", quality),
            Candidate(firstId, "A/song.mp3", quality)
        ]);

        Assert.Equal(firstId, result.CandidateId);
        Assert.Contains("stable path tie-breaker", result.Explanation);
    }

    [Fact]
    public void Recommend_DoesNotInventUnknownQualityFacts()
    {
        var unknownId = Guid.NewGuid();
        var result = MusicImportQualityRecommendation.Recommend([
            Candidate(unknownId, "a.unknown", new AudioQualityFacts(null, null, null, null, null, null, null, null))
        ]);

        Assert.Equal(unknownId, result.CandidateId);
        Assert.Contains("quality unknown", result.Explanation);
        Assert.DoesNotContain("0 kbps", result.Explanation);
        Assert.DoesNotContain("0-bit", result.Explanation);
    }

    [Fact]
    public void RecommendationModel_HasNoSelectionOrApprovalSideEffect()
    {
        var propertyNames = typeof(MusicImportRecommendation)
            .GetProperties()
            .Select(property => property.Name)
            .ToArray();

        Assert.DoesNotContain("Selected", propertyNames);
        Assert.DoesNotContain("Approved", propertyNames);
        Assert.DoesNotContain("Decision", propertyNames);
    }

    [Fact]
    public void ImportItem_CarriesExtractedQualityFactsWithoutASelection()
    {
        var item = new MusicImportItem
        {
            RelativePath = "album/song.flac",
            OriginalFileName = "song.flac",
            Extension = ".flac",
            Codec = "flac",
            Container = "flac",
            IsLossless = true,
            SampleRateHz = 96_000,
            BitDepth = 24,
            Channels = 2,
            BitRateKbps = 2_800
        };

        Assert.True(item.IsLossless);
        Assert.Null(item.Decision);
    }

    private static MusicImportRecommendationCandidate Candidate(
        Guid id,
        string relativePath,
        AudioQualityFacts quality,
        int metadataCompleteness = 3,
        int sourceStability = 2) =>
        new(id, relativePath, quality, metadataCompleteness, sourceStability);

    private static AudioQualityFacts Lossless(int bitDepth, int sampleRate) =>
        new("flac", "flac", true, sampleRate, bitDepth, 2, 2_000, 30_000_000);

    private static AudioQualityFacts Lossy(int bitRateKbps) =>
        new("mp3", "mp3", false, 44_100, null, 2, bitRateKbps, 8_000_000);
}
