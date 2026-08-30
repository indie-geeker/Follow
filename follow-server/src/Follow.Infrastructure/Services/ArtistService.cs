using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Artist management service
/// </summary>
public class ArtistService : IArtistService
{
    private readonly FollowDbContext _context;
    private readonly IStorageService _storageService;
    private readonly StorageDeletionQueue _deletionQueue;
    private readonly ILogger<ArtistService> _logger;

    public ArtistService(
        FollowDbContext context,
        IStorageService storageService,
        StorageDeletionQueue deletionQueue,
        ILogger<ArtistService> logger)
    {
        _context = context;
        _storageService = storageService;
        _deletionQueue = deletionQueue;
        _logger = logger;
    }

    public async Task<List<ArtistDto>> GetArtistsAsync()
    {
        var artists = await _context.Artists
            .AsNoTracking()
            .OrderBy(a => a.Name)
            .ThenBy(a => a.Id)
            .ToListAsync();

        return artists.Select(a => new ArtistDto(a.Id, a.Name, a.CoverUrl, a.Bio)).ToList();
    }

    public async Task<ArtistDto?> GetArtistByIdAsync(Guid id)
    {
        var artist = await _context.Artists
            .AsNoTracking()
            .FirstOrDefaultAsync(item => item.Id == id);
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

        _deletionQueue.TryEnqueue(artist.CoverUrl);
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

        return artist;
    }

    public async Task<string> UploadArtistCoverAsync(Guid id, Stream fileStream, string fileName, string contentType)
    {
        var artist = await _context.Artists.FindAsync(id);
        if (artist == null)
            throw new ArgumentException($"Artist {id} not found");

        var oldCoverPath = artist.CoverUrl;
        var coverPath = await _storageService.UploadFileAsync(fileStream, fileName, contentType, $"artists/{id}/cover");
        artist.CoverUrl = coverPath;
        _deletionQueue.TryEnqueue(oldCoverPath);
        try
        {
            await _context.SaveChangesAsync();
        }
        catch
        {
            await _deletionQueue.CompensateUploadAsync(_storageService, coverPath);
            throw;
        }

        _logger.LogInformation("Uploaded cover for artist {ArtistId}: {Path}", id, coverPath);
        return coverPath;
    }
}
