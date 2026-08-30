using Follow.Core.Interfaces;
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
}
