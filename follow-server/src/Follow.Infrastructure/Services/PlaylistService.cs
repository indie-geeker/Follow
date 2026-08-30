using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Playlist management service
/// </summary>
public class PlaylistService : IPlaylistService
{
    private readonly FollowDbContext _context;

    public PlaylistService(FollowDbContext context)
    {
        _context = context;
    }

    public async Task<List<PlaylistDto>> GetUserPlaylistsAsync(Guid userId)
    {
        var playlists = await _context.Playlists
            .AsNoTracking()
            .Where(p => p.UserId == userId || p.IsPublic)
            .Include(p => p.User)
            .Include(p => p.PlaylistTracks)
            .OrderByDescending(p => p.CreatedAt)
            .ThenBy(p => p.Id)
            .ToListAsync();

        return playlists.Select(p => ToDto(p, userId)).ToList();
    }

    public async Task<PlaylistDetailDto?> GetPlaylistByIdAsync(Guid id, Guid userId)
    {
        var playlist = await _context.Playlists
            .AsNoTracking()
            .Include(p => p.User)
            .Include(p => p.PlaylistTracks)
                .ThenInclude(pt => pt.Track)
                    .ThenInclude(t => t.Artist)
            .Include(p => p.PlaylistTracks)
                .ThenInclude(pt => pt.Track)
                    .ThenInclude(t => t.Album)
            .FirstOrDefaultAsync(p => p.Id == id && (p.UserId == userId || p.IsPublic));

        if (playlist == null) return null;

        var tracks = playlist.PlaylistTracks
            .OrderBy(pt => pt.Position)
            .Select(pt => new TrackDto(
                pt.Track.Id,
                pt.Track.Title,
                pt.Track.DurationSeconds,
                pt.Track.CoverUrl,
                pt.Track.LyricsUrl,
                pt.Track.BitRate,
                pt.Track.Format,
                pt.Track.Artist != null 
                    ? new ArtistDto(pt.Track.Artist.Id, pt.Track.Artist.Name, pt.Track.Artist.CoverUrl, pt.Track.Artist.Bio) 
                    : null,
                pt.Track.Album != null 
                    ? new AlbumDto(pt.Track.Album.Id, pt.Track.Album.Title, pt.Track.Album.Year, pt.Track.Album.CoverUrl, null) 
                    : null,
                pt.Track.CreatedAt
            )).ToList();

        return new PlaylistDetailDto(
            playlist.Id,
            playlist.Name,
            playlist.Description,
            playlist.CoverUrl,
            playlist.IsPublic,
            tracks,
            playlist.CreatedAt,
            playlist.UserId,
            playlist.User.Username,
            playlist.UserId == userId,
            playlist.UserId == userId
        );
    }

    public async Task<PlaylistDto> CreatePlaylistAsync(Guid userId, CreatePlaylistRequest request)
    {
        var playlist = new Playlist
        {
            Name = request.Name,
            Description = request.Description,
            IsPublic = request.IsPublic,
            UserId = userId
        };

        _context.Playlists.Add(playlist);
        await _context.SaveChangesAsync();

        var ownerName = await _context.Users
            .AsNoTracking()
            .Where(user => user.Id == userId)
            .Select(user => user.Username)
            .SingleAsync();
        return ToDto(playlist, userId, ownerName);
    }

    public async Task<PlaylistDto?> UpdatePlaylistAsync(Guid id, Guid userId, UpdatePlaylistRequest request)
    {
        var playlist = await _context.Playlists
            .Include(p => p.User)
            .Include(p => p.PlaylistTracks)
            .FirstOrDefaultAsync(p => p.Id == id && p.UserId == userId);

        if (playlist == null) return null;

        playlist.Name = request.Name;
        playlist.Description = request.Description;
        playlist.IsPublic = request.IsPublic;

        await _context.SaveChangesAsync();

        return ToDto(playlist, userId);
    }

    public async Task<bool> DeletePlaylistAsync(Guid id, Guid userId)
    {
        var playlist = await _context.Playlists
            .FirstOrDefaultAsync(p => p.Id == id && p.UserId == userId);

        if (playlist == null) return false;

        _context.Playlists.Remove(playlist);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<bool> AddTrackToPlaylistAsync(Guid playlistId, Guid trackId, Guid userId)
    {
        var playlist = await _context.Playlists
            .Include(p => p.PlaylistTracks)
            .FirstOrDefaultAsync(p => p.Id == playlistId && p.UserId == userId);

        if (playlist == null) return false;

        // Check if track exists
        var trackExists = await _context.Tracks.AnyAsync(t => t.Id == trackId);
        if (!trackExists) return false;

        // Check if track already in playlist
        if (playlist.PlaylistTracks.Any(pt => pt.TrackId == trackId)) return true;

        var maxPosition = playlist.PlaylistTracks.Count > 0 
            ? playlist.PlaylistTracks.Max(pt => pt.Position) + 1 
            : 0;

        var playlistTrack = new PlaylistTrack
        {
            PlaylistId = playlistId,
            TrackId = trackId,
            Position = maxPosition
        };

        _context.PlaylistTracks.Add(playlistTrack);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<bool> RemoveTrackFromPlaylistAsync(Guid playlistId, Guid trackId, Guid userId)
    {
        var playlist = await _context.Playlists
            .FirstOrDefaultAsync(p => p.Id == playlistId && p.UserId == userId);

        if (playlist == null) return false;

        var playlistTrack = await _context.PlaylistTracks
            .FirstOrDefaultAsync(pt => pt.PlaylistId == playlistId && pt.TrackId == trackId);

        if (playlistTrack == null) return false;

        _context.PlaylistTracks.Remove(playlistTrack);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<bool> ReorderTracksAsync(Guid playlistId, Guid userId, List<Guid> trackIds)
    {
        ArgumentNullException.ThrowIfNull(trackIds);
        var playlist = await _context.Playlists
            .Include(p => p.PlaylistTracks)
            .FirstOrDefaultAsync(p => p.Id == playlistId && p.UserId == userId);

        if (playlist == null) return false;

        var currentTrackIds = playlist.PlaylistTracks
            .Select(item => item.TrackId)
            .ToHashSet();
        if (trackIds.Count != playlist.PlaylistTracks.Count ||
            trackIds.Distinct().Count() != trackIds.Count ||
            !currentTrackIds.SetEquals(trackIds))
        {
            throw new ArgumentException("trackIds 必须是歌单全部曲目的唯一完整排列");
        }

        for (int i = 0; i < trackIds.Count; i++)
        {
            var playlistTrack = playlist.PlaylistTracks.Single(pt => pt.TrackId == trackIds[i]);
            playlistTrack.Position = i;
        }

        await _context.SaveChangesAsync();
        return true;
    }

    private static PlaylistDto ToDto(
        Playlist playlist,
        Guid currentUserId,
        string? ownerName = null)
    {
        var isOwner = playlist.UserId == currentUserId;
        return new PlaylistDto(
            playlist.Id,
            playlist.Name,
            playlist.Description,
            playlist.CoverUrl,
            playlist.IsPublic,
            playlist.PlaylistTracks.Count,
            playlist.CreatedAt,
            playlist.UserId,
            ownerName ?? playlist.User.Username,
            isOwner,
            isOwner);
    }
}
