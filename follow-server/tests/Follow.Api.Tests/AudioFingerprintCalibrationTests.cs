using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Core.Options;
using Follow.Core.Services;
using Follow.Infrastructure.Options;
using Follow.Infrastructure.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit.Abstractions;

namespace Follow.Api.Tests;

public class AudioFingerprintCalibrationTests
{
    private readonly ITestOutputHelper _output;

    public AudioFingerprintCalibrationTests(ITestOutputHelper output)
    {
        _output = output;
    }

    [Fact]
    public async Task GeneratedMatrixRequiresASeparatingMarginBeforeSettingThreshold()
    {
        var executablePath = Environment.GetEnvironmentVariable("FOLLOW_TEST_FPCALC");
        if (string.IsNullOrWhiteSpace(executablePath))
        {
            _output.WriteLine(
                "SKIPPED: set FOLLOW_TEST_FPCALC to run the real generated-audio calibration gate.");
            return;
        }

        await using var fixture = await GeneratedAudioFixture.CreateAsync();
        Assert.All(fixture.PositiveVariants, path => Assert.True(File.Exists(path)));
        Assert.All(fixture.NegativeVariants, path => Assert.True(File.Exists(path)));

        var service = new FpcalcAudioFingerprintService(
            Options.Create(new AudioFingerprintOptions
            {
                ExecutablePath = executablePath,
                Algorithm = 2,
                MaximumLengthSeconds = 120,
                Timeout = TimeSpan.FromSeconds(30),
                MaximumStandardOutputBytes = 2 * 1024 * 1024,
                MaximumStandardErrorBytes = 16 * 1024,
                RequiredVersionPrefix = "1.6."
            }),
            NullLogger<FpcalcAudioFingerprintService>.Instance);
        var fingerprints = new Dictionary<string, AudioFingerprint>(StringComparer.Ordinal);
        foreach (var path in fixture.PositiveVariants.Concat(fixture.NegativeVariants))
        {
            await using var source = File.OpenRead(path);
            AudioMetadata metadata;
            try
            {
                metadata = await new TagLibAudioMetadataExtractor().ExtractAsync(
                    source,
                    Path.GetFileName(path));
            }
            catch (Exception exception)
            {
                throw new InvalidOperationException(
                    $"Metadata extraction failed for {Path.GetFileName(path)}.",
                    exception);
            }
            source.Position = 0;
            fingerprints[path] = await service.ExtractAsync(
                source,
                TimeSpan.FromSeconds(metadata.DurationSeconds));
        }

        var reference = fingerprints[fixture.ReferenceFile];
        var scoringOptions = new AudioFingerprintStructuralOptions(
            CandidateSimilarityThreshold: 0.85,
            MatchSimilarityThreshold: 0.99,
            MinimumSegmentSimilarity: 0.98,
            MinimumCoverageFraction: 0.85,
            MaximumDurationDifference: TimeSpan.FromSeconds(2),
            MaximumAlignmentOffsetFrames: 2,
            MaximumCandidateAlignmentOffsetFrames: 512,
            SegmentCount: 3);
        var positiveScores = fixture.PositiveVariants
            .Where(path => path != fixture.ReferenceFile)
            .Select(path => Score(path, reference, fingerprints[path], scoringOptions))
            .ToArray();
        var negativeScores = fixture.NegativeVariants
            .Select(path => Score(path, reference, fingerprints[path], scoringOptions))
            .ToArray();
        var minimumPositiveSegment = positiveScores.Min(result => result.MinimumSegmentSimilarity);
        var maximumNegativeSegment = negativeScores.Max(result => result.MinimumSegmentSimilarity);
        var segmentMargin = minimumPositiveSegment - maximumNegativeSegment;

        foreach (var result in positiveScores)
        {
            _output.WriteLine(
                $"POSITIVE {Path.GetFileName(result.Path)} overall={result.OverallSimilarity:F6} " +
                $"minSegment={result.MinimumSegmentSimilarity:F6} coverage={result.CoverageFraction:F6} " +
                $"offset={result.OffsetFrames} disposition={result.Disposition}");
        }
        foreach (var result in negativeScores)
        {
            _output.WriteLine(
                $"NEGATIVE {Path.GetFileName(result.Path)} overall={result.OverallSimilarity:F6} " +
                $"minSegment={result.MinimumSegmentSimilarity:F6} coverage={result.CoverageFraction:F6} " +
                $"offset={result.OffsetFrames} disposition={result.Disposition}");
        }
        _output.WriteLine(
            $"MIN_POSITIVE_SEGMENT={minimumPositiveSegment:F6} " +
            $"MAX_NEGATIVE_SEGMENT={maximumNegativeSegment:F6} SEGMENT_MARGIN={segmentMargin:F6}");

        Assert.All(positiveScores, result =>
            Assert.Equal(AudioFingerprintMatchDisposition.Match, result.Disposition));
        Assert.All(negativeScores, result =>
            Assert.NotEqual(AudioFingerprintMatchDisposition.Match, result.Disposition));
        Assert.True(
            segmentMargin >= 0.03,
            $"No safe structural fingerprint margin: minimum positive segment " +
            $"{minimumPositiveSegment:F6}, maximum negative segment " +
            $"{maximumNegativeSegment:F6}, margin {segmentMargin:F6}.");
    }

    private static CalibrationScore Score(
        string path,
        AudioFingerprint reference,
        AudioFingerprint candidate,
        AudioFingerprintStructuralOptions options)
    {
        var result = AudioFingerprintStructuralSimilarity.Compare(reference, candidate, options);
        return new CalibrationScore(
            path,
            result.Measurement.OverallSimilarity,
            result.Measurement.SegmentSimilarities.Min(),
            result.Measurement.CoverageFraction,
            result.Measurement.OffsetFrames,
            result.Match.Disposition);
    }

    private sealed record CalibrationScore(
        string Path,
        double OverallSimilarity,
        double MinimumSegmentSimilarity,
        double CoverageFraction,
        int OffsetFrames,
        AudioFingerprintMatchDisposition Disposition);
}
