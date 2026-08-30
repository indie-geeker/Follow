using Follow.Infrastructure.Services;

namespace Follow.Api.Tests;

public class ImportObjectPathContractTests
{
    [Theory]
    [InlineData("tracks/import/item-id/audio.mp3")]
    [InlineData("tracks/import/0123456789/audio.flac")]
    public void ImportObjectPath_AcceptsOnlyManagedRelativeKeys(string objectPath)
    {
        MinioStorageService.ValidateImportObjectPath(objectPath);
    }

    [Theory]
    [InlineData("tracks/other/audio.mp3")]
    [InlineData("covers/import/item/audio.mp3")]
    [InlineData("/tracks/import/item/audio.mp3")]
    [InlineData("tracks/import/../audio.mp3")]
    [InlineData("tracks/import/item\\audio.mp3")]
    [InlineData("tracks/import//audio.mp3")]
    [InlineData("https://storage/tracks/import/item/audio.mp3")]
    public void ImportObjectPath_RejectsUnmanagedOrAmbiguousKeys(string objectPath)
    {
        Assert.Throws<ArgumentException>(() =>
            MinioStorageService.ValidateImportObjectPath(objectPath));
    }
}
