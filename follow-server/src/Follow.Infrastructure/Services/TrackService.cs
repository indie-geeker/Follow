using Follow.Core.Entities;
using Follow.Core.Interfaces;
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
    private readonly ILogger<TrackService> _logger;

    public TrackService(
        FollowDbContext context,
        IStorageService storageService,
        IArtistService artistService,
        IAlbumService albumService,
        ILogger<TrackService> logger)
    {
        _context = context;
        _storageService = storageService;
        _artistService = artistService;
        _albumService = albumService;
        _logger = logger;
    }

    public async Task<TrackDto> UploadTrackAsync(Stream fileStream, string fileName, string contentType)
    {
        // Save to temporary file for TagLib processing
        var tempPath = Path.GetTempFileName();
        var extension = Path.GetExtension(fileName).ToLowerInvariant();
        var tempFile = Path.ChangeExtension(tempPath, extension);
        
        try
        {
            // Copy stream to temp file
            await using (var fileWriter = System.IO.File.Create(tempFile))
            {
                await fileStream.CopyToAsync(fileWriter);
            }

            // Extract metadata using TagLib
            string title = Path.GetFileNameWithoutExtension(fileName);
            string? artistName = null;
            string? albumName = null;
            int durationSeconds = 0;
            int bitRate = 0;
            string? format = extension.TrimStart('.');
            byte[]? coverData = null;
            string? coverExtension = null;
            string? coverContentType = null;

            try
            {
                using var tagFile = TagLib.File.Create(tempFile);
                if (!string.IsNullOrWhiteSpace(tagFile.Tag.Title))
                    title = tagFile.Tag.Title;
                
                if (tagFile.Tag.Performers?.Length > 0)
                    artistName = tagFile.Tag.Performers[0];
                
                if (!string.IsNullOrWhiteSpace(tagFile.Tag.Album))
                    albumName = tagFile.Tag.Album;
                
                durationSeconds = (int)tagFile.Properties.Duration.TotalSeconds;
                bitRate = tagFile.Properties.AudioBitrate;

                if (tagFile.Tag.Pictures.Length > 0)
                {
                    try 
                    {
                        var pic = tagFile.Tag.Pictures[0];
                        coverData = pic.Data.Data;
                        coverContentType = pic.MimeType;
                        coverExtension = coverContentType switch 
                        {
                            "image/jpeg" => ".jpg",
                            "image/png" => ".png",
                            "image/webp" => ".webp",
                            "image/gif" => ".gif",
                            _ => null
                        };
                    }
                    catch (Exception ex)
                    {
                         _logger.LogWarning(ex, "Could not extract cover art from {FileName}", fileName);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not extract metadata from {FileName}", fileName);
            }

            // Upload to MinIO
            await using var uploadStream = System.IO.File.OpenRead(tempFile);
            var filePath = await _storageService.UploadFileAsync(uploadStream, fileName, contentType, "tracks");

            // Get or create artist
            Artist? artist = null;
            if (!string.IsNullOrWhiteSpace(artistName))
            {
                artist = await _artistService.GetOrCreateArtistByNameAsync(artistName);
            }

            // Get or create album
            Album? album = null;
            if (!string.IsNullOrWhiteSpace(albumName))
            {
                album = await _albumService.GetOrCreateAlbumAsync(albumName, artist?.Id);
            }

            // Create track entity
            var track = new Track
            {
                Title = title,
                FilePath = filePath,
                DurationSeconds = durationSeconds,
                BitRate = bitRate,
                Format = format,
                ArtistId = artist?.Id,
                AlbumId = album?.Id
            };

            _context.Tracks.Add(track);
            await _context.SaveChangesAsync();

            // Upload cover if extracted
            if (coverData != null && coverExtension != null && coverContentType != null)
            {
                try 
                {
                    using var coverStream = new MemoryStream(coverData);
                    var coverPath = await _storageService.UploadFileAsync(coverStream, $"cover{coverExtension}", coverContentType, $"covers/{track.Id}");
                    track.CoverUrl = coverPath;
                    await _context.SaveChangesAsync();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to upload extracted cover for track {TrackId}", track.Id);
                }
            }

            _logger.LogInformation("Uploaded track: {Title} by {Artist}", title, artistName ?? "Unknown");

            return MapToDto(track, artist, album);
        }
        finally
        {
            // Cleanup temp files
            if (System.IO.File.Exists(tempFile))
                System.IO.File.Delete(tempFile);
            if (System.IO.File.Exists(tempPath))
                System.IO.File.Delete(tempPath);
        }
    }

    public async Task<(List<TrackDto> Tracks, int TotalCount)> GetTracksAsync(int page = 1, int pageSize = 20, string? search = null)
    {
        var query = _context.Tracks
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

        var totalCount = await query.CountAsync();
        
        var tracks = await query
            .OrderByDescending(t => t.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return (tracks.Select(t => MapToDto(t, t.Artist, t.Album)).ToList(), totalCount);
    }

    public async Task<TrackDto?> GetTrackByIdAsync(Guid id)
    {
        var track = await _context.Tracks
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

        if (request.CoverUrl != null)
            track.CoverUrl = request.CoverUrl;

        if (request.LyricsUrl != null)
            track.LyricsUrl = request.LyricsUrl;

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

        // Delete from storage
        await _storageService.DeleteFileAsync(track.FilePath);

        _context.Tracks.Remove(track);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Deleted track: {TrackId}", id);
        return true;
    }

    public async Task<(Stream? Stream, string? ContentType, long? Length)> GetTrackStreamAsync(Guid id)
    {
        var track = await _context.Tracks.FindAsync(id);
        if (track == null) return (null, null, null);

        var stream = await _storageService.GetFileAsync(track.FilePath);
        if (stream == null) return (null, null, null);

        var contentType = GetContentType(track.Format);
        return (stream, contentType, stream.Length);
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

        // Delete old cover if exists
        if (!string.IsNullOrEmpty(track.CoverUrl))
        {
            await _storageService.DeleteFileAsync(track.CoverUrl);
        }

        // Upload new cover
        var coverPath = await _storageService.UploadFileAsync(fileStream, fileName, contentType, $"covers/{trackId}");
        track.CoverUrl = coverPath;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Uploaded cover for track {TrackId}: {Path}", trackId, coverPath);
        return coverPath;
    }

    public async Task<string> UploadTrackLyricsAsync(Guid trackId, Stream fileStream, string fileName, string contentType)
    {
        var track = await _context.Tracks.FindAsync(trackId);
        if (track == null)
            throw new ArgumentException($"Track {trackId} not found");

        // Delete old lyrics if exists
        if (!string.IsNullOrEmpty(track.LyricsUrl))
        {
            await _storageService.DeleteFileAsync(track.LyricsUrl);
        }

        // Upload new lyrics
        var lyricsPath = await _storageService.UploadFileAsync(fileStream, fileName, contentType, $"lyrics/{trackId}");
        track.LyricsUrl = lyricsPath;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Uploaded lyrics for track {TrackId}: {Path}", trackId, lyricsPath);
        return lyricsPath;
    }

    public async Task<(Stream? Stream, string? ContentType)?> GetLyricsStreamAsync(Guid trackId)
    {
        var track = await _context.Tracks.FindAsync(trackId);
        if (track == null || string.IsNullOrEmpty(track.LyricsUrl))
            return null;

        var stream = await _storageService.GetFileAsync(track.LyricsUrl);
        if (stream == null)
            return null;

        return (stream, "text/plain; charset=utf-8");
    }

    public async Task<List<TagDto>> GetTrackTagsAsync(Guid trackId)
    {
        return await _context.TrackTags
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
