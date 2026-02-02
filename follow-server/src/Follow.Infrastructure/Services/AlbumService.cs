using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Album management service
/// </summary>
public class AlbumService : IAlbumService
{
    private readonly FollowDbContext _context;
    private readonly IStorageService _storageService;
    private readonly ILogger<AlbumService> _logger;

    public AlbumService(
        FollowDbContext context,
        IStorageService storageService,
        ILogger<AlbumService> logger)
    {
        _context = context;
        _storageService = storageService;
        _logger = logger;
    }

    public async Task<List<AlbumDto>> GetAlbumsAsync()
    {
        var albums = await _context.Albums
            .Include(a => a.Artist)
            .OrderBy(a => a.Title)
            .ToListAsync();

        return albums.Select(a => new AlbumDto(
            a.Id, 
            a.Title, 
            a.Year, 
            a.CoverUrl,
            a.Artist != null ? new ArtistDto(a.Artist.Id, a.Artist.Name, a.Artist.CoverUrl, a.Artist.Bio) : null
        )).ToList();
    }

    public async Task<AlbumDto?> GetAlbumByIdAsync(Guid id)
    {
        var album = await _context.Albums
            .Include(a => a.Artist)
            .FirstOrDefaultAsync(a => a.Id == id);
        
        if (album == null) return null;

        return new AlbumDto(
            album.Id, 
            album.Title, 
            album.Year, 
            album.CoverUrl,
            album.Artist != null ? new ArtistDto(album.Artist.Id, album.Artist.Name, album.Artist.CoverUrl, album.Artist.Bio) : null
        );
    }

    public async Task<AlbumDto> CreateAlbumAsync(CreateAlbumRequest request)
    {
        var album = new Album
        {
            Title = request.Title,
            Year = request.Year,
            ArtistId = request.ArtistId
        };

        _context.Albums.Add(album);
        await _context.SaveChangesAsync();

        if (request.ArtistId.HasValue)
        {
            await _context.Entry(album).Reference(a => a.Artist).LoadAsync();
        }

        return new AlbumDto(
            album.Id, 
            album.Title, 
            album.Year, 
            album.CoverUrl,
            album.Artist != null ? new ArtistDto(album.Artist.Id, album.Artist.Name, album.Artist.CoverUrl, album.Artist.Bio) : null
        );
    }

    public async Task<AlbumDto?> UpdateAlbumAsync(Guid id, UpdateAlbumRequest request)
    {
        var album = await _context.Albums.FindAsync(id);
        if (album == null) return null;

        album.Title = request.Title;
        album.Year = request.Year;
        album.ArtistId = request.ArtistId;

        if (request.CoverUrl != null)
        {
            album.CoverUrl = request.CoverUrl;
        }

        await _context.SaveChangesAsync();
        await _context.Entry(album).Reference(a => a.Artist).LoadAsync();

        return new AlbumDto(
            album.Id, 
            album.Title, 
            album.Year, 
            album.CoverUrl,
            album.Artist != null ? new ArtistDto(album.Artist.Id, album.Artist.Name, album.Artist.CoverUrl, album.Artist.Bio) : null
        );
    }

    public async Task<bool> DeleteAlbumAsync(Guid id)
    {
        var album = await _context.Albums.FindAsync(id);
        if (album == null) return false;

        _context.Albums.Remove(album);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<Album?> GetOrCreateAlbumAsync(string title, Guid? artistId)
    {
        var album = await _context.Albums.FirstOrDefaultAsync(a => a.Title == title && a.ArtistId == artistId);
        if (album != null) return album;

        album = new Album { Title = title, ArtistId = artistId };
        _context.Albums.Add(album);
        await _context.SaveChangesAsync();

        return album;
    }

    public async Task<string> UploadAlbumCoverAsync(Guid id, Stream fileStream, string fileName, string contentType)
    {
        var album = await _context.Albums.FindAsync(id);
        if (album == null)
            throw new ArgumentException($"Album {id} not found");

        if (!string.IsNullOrEmpty(album.CoverUrl) && !album.CoverUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase))
        {
            await _storageService.DeleteFileAsync(album.CoverUrl);
        }

        var coverPath = await _storageService.UploadFileAsync(fileStream, fileName, contentType, $"albums/{id}/cover");
        album.CoverUrl = coverPath;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Uploaded cover for album {AlbumId}: {Path}", id, coverPath);
        return coverPath;
    }
}
