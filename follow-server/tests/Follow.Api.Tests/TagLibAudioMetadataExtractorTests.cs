using Follow.Infrastructure.Services;

namespace Follow.Api.Tests;

public sealed class TagLibAudioMetadataExtractorTests
{
    private const string TimedLyrics =
        "[00:12.00]<00:12.00>我<00:12.30>爱<00:12.550>你";
    private static readonly byte[] CoverBytes = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=");

    [Fact]
    public async Task ExtractAsync_ReturnsCoreMetadataCoverAndTimedLyrics()
    {
        var path = await CreateSyntheticTaggedMp3Async();
        try
        {
            await using var stream = File.OpenRead(path);
            var metadata = await new TagLibAudioMetadataExtractor()
                .ExtractAsync(stream, "synthetic-tagged.mp3", CancellationToken.None);

            Assert.Equal("Synthetic title", metadata.Title);
            Assert.Equal("Synthetic artist", metadata.Artist);
            Assert.Equal("Synthetic album", metadata.Album);
            Assert.Equal("mp3", metadata.Format);
            Assert.True(metadata.DurationSeconds > 0);
            Assert.Equal("image/png", metadata.CoverContentType);
            Assert.Equal(CoverBytes, metadata.CoverData);
            Assert.Equal(TimedLyrics, metadata.TimedLyrics);
        }
        finally
        {
            File.Delete(path);
        }
    }

    private static async Task<string> CreateSyntheticTaggedMp3Async()
    {
        var fixturePath = Path.Combine(
            AppContext.BaseDirectory,
            "Fixtures",
            "synthetic-silent.mp3.b64");
        var audioBytes = Convert.FromBase64String(await File.ReadAllTextAsync(fixturePath));
        var path = Path.Combine(Path.GetTempPath(), $"follow-{Guid.NewGuid():N}.mp3");
        await File.WriteAllBytesAsync(path, audioBytes);

        using var tagFile = TagLib.File.Create(path);
        tagFile.Tag.Title = "Synthetic title";
        tagFile.Tag.Performers = ["Synthetic artist"];
        tagFile.Tag.Album = "Synthetic album";
        tagFile.Tag.Lyrics = TimedLyrics;
        tagFile.Tag.Pictures =
        [
            new TagLib.Picture(new TagLib.ByteVector(CoverBytes))
            {
                Type = TagLib.PictureType.FrontCover,
                MimeType = "image/png",
                Description = "Synthetic cover"
            }
        ];
        tagFile.Save();
        return path;
    }
}
