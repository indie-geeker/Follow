using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using TagLib;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Track management service with audio metadata extraction
/// </summary>
public class TrackService : ITrackService
{
    private readonly FollowDbContext _context;
    private readonly IStorageService _storageService;
    private readonly IArtistService _artistService;
    private readonly IAlbumService _albumService;
    private readonly StorageDeletionQueue _deletionQueue;
    private readonly ILogger<TrackService> _logger;

    public TrackService(
        FollowDbContext context,
        IStorageService storageService,
        IArtistService artistService,
        IAlbumService albumService,
        StorageDeletionQueue deletionQueue,
        ILogger<TrackService> logger)
    {
        _context = context;
        _storageService = storageService;
        _artistService = artistService;
        _albumService = albumService;
        _deletionQueue = deletionQueue;
        _logger = logger;
    }

    public async Task<(List<TrackDto> Tracks, int TotalCount)> GetTracksAsync(int page = 1, int pageSize = 20, string? search = null, Guid? artistId = null, Guid? albumId = null)
    {
        var offset = PaginationPolicy.GetOffset(page, pageSize);
        var query = _context.Tracks
            .AsNoTracking()
            .Include(t => t.Artist)
            .Include(t => t.Album)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var searchLower = search.ToLower();
            query = query.Where(t => 
                t.Title.ToLower().Contains(searchLower) ||
                (t.Artist != null && t.Artist.Name.ToLower().Contains(searchLower)) ||
                (t.Album != null && t.Album.Title.ToLower().Contains(searchLower)));
        }

        if (artistId.HasValue)
        {
            query = query.Where(t => t.ArtistId == artistId.Value);
        }

        if (albumId.HasValue)
        {
            query = query.Where(t => t.AlbumId == albumId.Value);
        }

        var totalCount = await query.CountAsync();
        
        var tracks = await query
            .OrderByDescending(t => t.CreatedAt)
            .ThenBy(t => t.Id)
            .Skip(offset)
            .Take(pageSize)
            .ToListAsync();

        return (tracks.Select(t => MapToDto(t, t.Artist, t.Album)).ToList(), totalCount);
    }

    public async Task<TrackDto?> GetTrackByIdAsync(Guid id)
    {
        var track = await _context.Tracks
            .AsNoTracking()
            .Include(t => t.Artist)
            .Include(t => t.Album)
            .FirstOrDefaultAsync(t => t.Id == id);

        return track == null ? null : MapToDto(track, track.Artist, track.Album);
    }

    public async Task<TrackDto?> UpdateTrackAsync(Guid id, UpdateTrackRequest request)
    {
        var track = await _context.Tracks
            .Include(t => t.Artist)
            .Include(t => t.Album)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (track == null) return null;

        if (request.Title != null)
            track.Title = request.Title;
        
        if (request.ArtistId.HasValue)
            track.ArtistId = request.ArtistId.Value;
        
        if (request.AlbumId.HasValue)
            track.AlbumId = request.AlbumId.Value;

        await _context.SaveChangesAsync();

        // Reload with navigation properties
        await _context.Entry(track).Reference(t => t.Artist).LoadAsync();
        await _context.Entry(track).Reference(t => t.Album).LoadAsync();

        return MapToDto(track, track.Artist, track.Album);
    }

    public async Task<bool> DeleteTrackAsync(Guid id)
    {
        var track = await _context.Tracks.FindAsync(id);
        if (track == null) return false;

        _deletionQueue.Enqueue(track.FilePath);
        _deletionQueue.TryEnqueue(track.CoverUrl);
        _deletionQueue.TryEnqueue(track.LyricsUrl);
        _context.Tracks.Remove(track);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Deleted track: {TrackId}", id);
        return true;
    }

    public async Task<StoredObjectDescriptor?> GetTrackObjectAsync(Guid id)
    {
        var track = await _context.Tracks
            .AsNoTracking()
            .FirstOrDefaultAsync(item => item.Id == id);
        return track == null
            ? null
            : new StoredObjectDescriptor(track.FilePath, GetContentType(track.Format));
    }

    private static TrackDto MapToDto(Track track, Artist? artist, Album? album)
    {
        return new TrackDto(
            track.Id,
            track.Title,
            track.DurationSeconds,
            track.CoverUrl,
            track.LyricsUrl,
            track.BitRate,
            track.Format,
            artist != null ? new ArtistDto(artist.Id, artist.Name, artist.CoverUrl, artist.Bio) : null,
            album != null ? new AlbumDto(album.Id, album.Title, album.Year, album.CoverUrl, null) : null,
            track.CreatedAt);
    }

    private static string GetContentType(string? format)
    {
        return format?.ToLower() switch
        {
            "mp3" => "audio/mpeg",
            "flac" => "audio/flac",
            "wav" => "audio/wav",
            "aac" => "audio/aac",
            "ogg" => "audio/ogg",
            "m4a" => "audio/mp4",
            _ => "application/octet-stream"
        };
    }

    public async Task<string> UploadTrackCoverAsync(Guid trackId, Stream fileStream, string fileName, string contentType)
    {
        var track = await _context.Tracks.FindAsync(trackId);
        if (track == null)
            throw new ArgumentException($"Track {trackId} not found");

        var oldCoverPath = track.CoverUrl;
        var coverPath = await _storageService.UploadFileAsync(fileStream, fileName, contentType, $"covers/{trackId}");
        track.CoverUrl = coverPath;
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

        _logger.LogInformation("Uploaded cover for track {TrackId}: {Path}", trackId, coverPath);
        return coverPath;
    }

    internal async Task PersistExtractedCoverReferenceAsync(
        Track track,
        string coverPath)
    {
        var previousCoverPath = track.CoverUrl;
        track.CoverUrl = coverPath;
        try
        {
            await _context.SaveChangesAsync();
        }
        catch
        {
            track.CoverUrl = previousCoverPath;
            await _deletionQueue.CompensateUploadAsync(_storageService, coverPath);
            throw;
        }
    }

    public async Task<string> UploadTrackLyricsAsync(Guid trackId, Stream fileStream, string fileName, string contentType)
    {
        var track = await _context.Tracks.FindAsync(trackId);
        if (track == null)
            throw new ArgumentException($"Track {trackId} not found");

        var oldLyricsPath = track.LyricsUrl;
        var lyricsPath = await _storageService.UploadFileAsync(fileStream, fileName, contentType, $"lyrics/{trackId}");
        track.LyricsUrl = lyricsPath;
        _deletionQueue.TryEnqueue(oldLyricsPath);
        try
        {
            await _context.SaveChangesAsync();
        }
        catch
        {
            await _deletionQueue.CompensateUploadAsync(_storageService, lyricsPath);
            throw;
        }

        _logger.LogInformation("Uploaded lyrics for track {TrackId}: {Path}", trackId, lyricsPath);
        return lyricsPath;
    }

    public async Task<StoredObjectDescriptor?> GetLyricsObjectAsync(Guid trackId)
    {
        var track = await _context.Tracks
            .AsNoTracking()
            .FirstOrDefaultAsync(item => item.Id == trackId);
        if (track == null || string.IsNullOrEmpty(track.LyricsUrl))
            return null;

        return new StoredObjectDescriptor(track.LyricsUrl, "text/plain; charset=utf-8");
    }

    public async Task<List<TagDto>> GetTrackTagsAsync(Guid trackId)
    {
        return await _context.TrackTags
            .AsNoTracking()
            .Where(tt => tt.TrackId == trackId)
            .Select(tt => new TagDto(
                tt.Tag.Id,
                tt.Tag.Name,
                tt.Tag.Category,
                tt.Tag.CoverUrl,
                tt.Tag.TrackTags.Count,
                tt.Tag.CreatedAt
            ))
            .ToListAsync();
    }

    public async Task<bool> SetTrackTagsAsync(Guid trackId, List<Guid> tagIds)
    {
        var track = await _context.Tracks.FindAsync(trackId);
        if (track == null) return false;

        // Remove existing tags
        var existingTags = await _context.TrackTags
            .Where(tt => tt.TrackId == trackId)
            .ToListAsync();
        _context.TrackTags.RemoveRange(existingTags);

        // Add new tags
        foreach (var tagId in tagIds)
        {
            var tagExists = await _context.Tags.AnyAsync(t => t.Id == tagId);
            if (tagExists)
            {
                _context.TrackTags.Add(new TrackTag
                {
                    TrackId = trackId,
                    TagId = tagId
                });
            }
        }

        await _context.SaveChangesAsync();
        return true;
    }
}
