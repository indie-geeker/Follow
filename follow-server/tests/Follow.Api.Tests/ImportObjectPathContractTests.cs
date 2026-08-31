using Follow.Infrastructure.Services;

namespace Follow.Api.Tests;

public class ImportObjectPathContractTests
{
    [Theory]
    [InlineData("tracks/import/item-id/audio.mp3")]
    [InlineData("tracks/import/0123456789/audio.flac")]
    [InlineData("tracks/staging/0123456789/source.flac")]
    public void ImportObjectPath_AcceptsOnlyManagedRelativeKeys(string objectPath)
    {
        MinioStorageService.ValidateImportObjectPath(objectPath);
    }

    [Fact]
    public void ImportObjectPath_BuildsIsolatedStagingKeyFromItemId()
    {
        var itemId = Guid.Parse("00112233-4455-6677-8899-aabbccddeeff");

        var path = ImportObjectPath.BuildStaging(itemId, ".FLAC");

        Assert.Equal("tracks/staging/00112233445566778899aabbccddeeff/source.flac", path);
        MinioStorageService.ValidateImportObjectPath(path);
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
