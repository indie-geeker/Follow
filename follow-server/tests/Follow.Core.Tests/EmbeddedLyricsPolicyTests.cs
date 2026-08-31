using Follow.Core.Services;

namespace Follow.Core.Tests;

public sealed class EmbeddedLyricsPolicyTests
{
    [Theory]
    [InlineData("[00:01.20]line", "[00:01.20]line")]
    [InlineData("[00:01.200]line", "[00:01.200]line")]
    [InlineData("\uFEFF[ar:artist]\r\n[00:01.20]line\r\n", "[ar:artist]\n[00:01.20]line")]
    public void Normalize_ReturnsBoundedDocumentsWithTimedLines(
        string input,
        string expected)
    {
        Assert.Equal(expected, EmbeddedLyricsPolicy.Normalize(input));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("[ar:artist]\n[al:album]")]
    [InlineData("plain unsynchronized lyrics")]
    public void Normalize_RejectsDocumentsWithoutTimedLines(string? input)
    {
        Assert.Null(EmbeddedLyricsPolicy.Normalize(input));
    }

    [Fact]
    public void Normalize_RejectsOversizedDocuments()
    {
        var oversized = $"[00:01.20]line{new string('x', EmbeddedLyricsPolicy.MaxUtf8Bytes)}";

        Assert.Null(EmbeddedLyricsPolicy.Normalize(oversized));
    }
}
