using Follow.Core.Services;

namespace Follow.Core.Tests;

public class AudioFilePolicyTests
{
    [Theory]
    [InlineData("song.MP3", "audio/mpeg")]
    [InlineData("song.flac", "audio/flac")]
    [InlineData("song.WAV", "audio/wav")]
    [InlineData("song.aac", "audio/aac")]
    [InlineData("song.OGG", "audio/ogg")]
    [InlineData("song.m4a", "audio/mp4")]
    public void TryGetCanonicalContentType_AcceptsSupportedExtensionsCaseInsensitively(
        string fileName,
        string expectedContentType)
    {
        Assert.True(AudioFilePolicy.TryGetCanonicalContentType(
            fileName,
            out var contentType));
        Assert.Equal(expectedContentType, contentType);
    }

    [Theory]
    [InlineData("song.txt")]
    [InlineData("song")]
    [InlineData("song.mp3.exe")]
    public void TryGetCanonicalContentType_RejectsUnsupportedExtensions(string fileName)
    {
        Assert.False(AudioFilePolicy.TryGetCanonicalContentType(
            fileName,
            out _));
    }

    [Fact]
    public void ValidateCandidate_RejectsZeroByteFile()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() =>
            AudioFilePolicy.ValidateCandidate("song.wav", sizeBytes: 0));
    }

    [Fact]
    public void ValidateCandidate_RejectsFileLargerThanConfiguredMaximum()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() =>
            AudioFilePolicy.ValidateCandidate(
                "song.wav",
                sizeBytes: 11,
                maximumFileBytes: 10));
    }

    [Fact]
    public void ValidateCandidate_RejectsPathLongerThanConfiguredMaximum()
    {
        Assert.Throws<ArgumentException>(() =>
            AudioFilePolicy.ValidateCandidate(
                "123456.wav",
                sizeBytes: 1,
                maximumRelativePathLength: 8));
    }
}
