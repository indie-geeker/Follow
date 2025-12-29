using Follow.Core.Entities;
using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for artist management
/// </summary>
public interface IArtistService
{
    Task<List<ArtistDto>> GetArtistsAsync();
    Task<ArtistDto?> GetArtistByIdAsync(Guid id);
    Task<ArtistDto> CreateArtistAsync(CreateArtistRequest request);
    Task<ArtistDto?> UpdateArtistAsync(Guid id, UpdateArtistRequest request);
    Task<bool> DeleteArtistAsync(Guid id);
    Task<Artist?> GetOrCreateArtistByNameAsync(string name);
}

/// <summary>
/// Interface for album management
/// </summary>
public interface IAlbumService
{
    Task<List<AlbumDto>> GetAlbumsAsync();
    Task<AlbumDto?> GetAlbumByIdAsync(Guid id);
    Task<AlbumDto> CreateAlbumAsync(CreateAlbumRequest request);
    Task<AlbumDto?> UpdateAlbumAsync(Guid id, UpdateAlbumRequest request);
    Task<bool> DeleteAlbumAsync(Guid id);
    Task<Album?> GetOrCreateAlbumAsync(string title, Guid? artistId);
}
