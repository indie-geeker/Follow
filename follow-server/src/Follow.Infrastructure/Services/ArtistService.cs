using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Artist management service
/// </summary>
public class ArtistService : IArtistService
{
    private readonly FollowDbContext _context;

    public ArtistService(FollowDbContext context)
    {
        _context = context;
    }

    public async Task<List<ArtistDto>> GetArtistsAsync()
    {
        var artists = await _context.Artists
            .OrderBy(a => a.Name)
            .ToListAsync();

        return artists.Select(a => new ArtistDto(a.Id, a.Name, a.CoverUrl, a.Bio)).ToList();
    }

    public async Task<ArtistDto?> GetArtistByIdAsync(Guid id)
    {
        var artist = await _context.Artists.FindAsync(id);
        return artist == null ? null : new ArtistDto(artist.Id, artist.Name, artist.CoverUrl, artist.Bio);
    }

    public async Task<ArtistDto> CreateArtistAsync(CreateArtistRequest request)
    {
        var artist = new Artist
        {
            Name = request.Name,
            Bio = request.Bio
        };

        _context.Artists.Add(artist);
        await _context.SaveChangesAsync();

        return new ArtistDto(artist.Id, artist.Name, artist.CoverUrl, artist.Bio);
    }

    public async Task<ArtistDto?> UpdateArtistAsync(Guid id, UpdateArtistRequest request)
    {
        var artist = await _context.Artists.FindAsync(id);
        if (artist == null) return null;

        artist.Name = request.Name;
        artist.Bio = request.Bio;

        await _context.SaveChangesAsync();

        return new ArtistDto(artist.Id, artist.Name, artist.CoverUrl, artist.Bio);
    }

    public async Task<bool> DeleteArtistAsync(Guid id)
    {
        var artist = await _context.Artists.FindAsync(id);
        if (artist == null) return false;

        _context.Artists.Remove(artist);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<Artist?> GetOrCreateArtistByNameAsync(string name)
    {
        var artist = await _context.Artists.FirstOrDefaultAsync(a => a.Name == name);
        if (artist != null) return artist;

        artist = new Artist { Name = name };
        _context.Artists.Add(artist);
        await _context.SaveChangesAsync();

        return artist;
    }
}
