using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

/// <summary>
/// User music features: favorites and play history
/// </summary>
public class UserMusicService : IUserMusicService
{
    private readonly FollowDbContext _context;

    public UserMusicService(FollowDbContext context)
    {
        _context = context;
    }

    public async Task<List<TrackDto>> GetFavoritesAsync(Guid userId)
    {
        var favorites = await _context.Favorites
            .Where(f => f.UserId == userId)
            .Include(f => f.Track)
                .ThenInclude(t => t.Artist)
            .Include(f => f.Track)
                .ThenInclude(t => t.Album)
            .OrderByDescending(f => f.CreatedAt)
            .ToListAsync();

        return favorites.Select(f => new TrackDto(
            f.Track.Id,
            f.Track.Title,
            f.Track.DurationSeconds,
            f.Track.CoverUrl,
            f.Track.LyricsUrl,
            f.Track.BitRate,
            f.Track.Format,
            f.Track.Artist != null 
                ? new ArtistDto(f.Track.Artist.Id, f.Track.Artist.Name, f.Track.Artist.CoverUrl, f.Track.Artist.Bio) 
                : null,
            f.Track.Album != null 
                ? new AlbumDto(f.Track.Album.Id, f.Track.Album.Title, f.Track.Album.Year, f.Track.Album.CoverUrl, null) 
                : null,
            f.Track.CreatedAt
        )).ToList();
    }

    public async Task<bool> AddToFavoritesAsync(Guid userId, Guid trackId)
    {
        if (await _context.Favorites.AnyAsync(f => f.UserId == userId && f.TrackId == trackId))
            return true;

        var trackExists = await _context.Tracks.AnyAsync(t => t.Id == trackId);
        if (!trackExists) return false;

        var favorite = new Favorite
        {
            UserId = userId,
            TrackId = trackId
        };

        _context.Favorites.Add(favorite);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<bool> RemoveFromFavoritesAsync(Guid userId, Guid trackId)
    {
        var favorite = await _context.Favorites
            .FirstOrDefaultAsync(f => f.UserId == userId && f.TrackId == trackId);

        if (favorite == null) return false;

        _context.Favorites.Remove(favorite);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<bool> IsFavoriteAsync(Guid userId, Guid trackId)
    {
        return await _context.Favorites
            .AnyAsync(f => f.UserId == userId && f.TrackId == trackId);
    }

    public async Task<List<PlayHistoryItemDto>> GetPlayHistoryAsync(Guid userId, int limit = 50)
    {
        var history = await _context.PlayHistories
            .Where(h => h.UserId == userId)
            .Include(h => h.Track)
                .ThenInclude(t => t.Artist)
            .OrderByDescending(h => h.PlayedAt)
            .Take(limit)
            .ToListAsync();

        return history.Select(h => new PlayHistoryItemDto(
            h.TrackId,
            h.Track.Title,
            h.Track.Artist != null 
                ? new ArtistDto(h.Track.Artist.Id, h.Track.Artist.Name, h.Track.Artist.CoverUrl, h.Track.Artist.Bio) 
                : null,
            h.PlayedAt,
            h.PlayDurationSeconds
        )).ToList();
    }

    public async Task AddToPlayHistoryAsync(Guid userId, Guid trackId, int playDurationSeconds)
    {
        var history = new PlayHistory
        {
            UserId = userId,
            TrackId = trackId,
            PlayedAt = DateTime.UtcNow,
            PlayDurationSeconds = playDurationSeconds
        };

        _context.PlayHistories.Add(history);
        await _context.SaveChangesAsync();
    }
}
