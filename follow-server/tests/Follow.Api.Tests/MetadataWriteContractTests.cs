using Follow.Core.Interfaces;
using Follow.Infrastructure.Services;
using Follow.Shared.DTOs;

namespace Follow.Api.Tests;

public class MetadataWriteContractTests
{
    [Theory]
    [InlineData(typeof(UpdateTrackRequest), "CoverUrl")]
    [InlineData(typeof(UpdateTrackRequest), "LyricsUrl")]
    [InlineData(typeof(UpdateArtistRequest), "CoverUrl")]
    [InlineData(typeof(UpdateAlbumRequest), "CoverUrl")]
    [InlineData(typeof(CreateTagRequest), "CoverUrl")]
    [InlineData(typeof(UpdateTagRequest), "CoverUrl")]
    public void MetadataRequests_CannotWriteManagedObjectPaths(Type requestType, string property)
    {
        Assert.Null(requestType.GetProperty(property));
    }

    [Fact]
    public async Task TagLibExtractor_ReturnsNormalizedQualityFactsAndExactDuration()
    {
        await using var fixture = await GeneratedAudioFixture.CreateAsync();
        var flacPath = Assert.Single(
            fixture.PositiveVariants,
            path => Path.GetFileName(path) == "reference.flac");
        await using var source = File.OpenRead(flacPath);

        var metadata = await new TagLibAudioMetadataExtractor().ExtractAsync(
            source,
            Path.GetFileName(flacPath));

        Assert.Equal("flac", metadata.Codec);
        Assert.Equal("flac", metadata.Container);
        Assert.True(metadata.IsLossless);
        Assert.Equal(44_100, metadata.SampleRateHz);
        Assert.Equal(16, metadata.BitDepth);
        Assert.Equal(1, metadata.Channels);
        Assert.True(metadata.BitRateKbps > 0);
        Assert.NotNull(metadata.ExactDurationMilliseconds);
        Assert.InRange(metadata.ExactDurationMilliseconds.Value, 17_900, 18_100);
        Assert.Equal(18, metadata.DurationSeconds);
    }

    [Fact]
    public async Task TagLibExtractor_HandlesGeneratedM4aCodecListContainingNullEntry()
    {
        await using var fixture = await GeneratedAudioFixture.CreateAsync();
        var m4aPath = Assert.Single(
            fixture.PositiveVariants,
            path => Path.GetExtension(path) == ".m4a");
        await using var source = File.OpenRead(m4aPath);

        var metadata = await new TagLibAudioMetadataExtractor().ExtractAsync(
            source,
            Path.GetFileName(m4aPath));

        Assert.Equal("m4a", metadata.Container);
        Assert.Equal("aac", metadata.Codec);
        Assert.False(metadata.IsLossless);
        Assert.Equal(44_100, metadata.SampleRateHz);
    }
}
