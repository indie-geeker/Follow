using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for playlist management
/// </summary>
public interface IPlaylistService
{
    /// <summary>
    /// Get all playlists for a user
    /// </summary>
    Task<List<PlaylistDto>> GetUserPlaylistsAsync(Guid userId);

    /// <summary>
    /// Get a playlist by ID with tracks
    /// </summary>
    Task<PlaylistDetailDto?> GetPlaylistByIdAsync(Guid id, Guid userId);

    /// <summary>
    /// Create a new playlist
    /// </summary>
    Task<PlaylistDto> CreatePlaylistAsync(Guid userId, CreatePlaylistRequest request);

    /// <summary>
    /// Update a playlist
    /// </summary>
    Task<PlaylistDto?> UpdatePlaylistAsync(Guid id, Guid userId, UpdatePlaylistRequest request);

    /// <summary>
    /// Delete a playlist
    /// </summary>
    Task<bool> DeletePlaylistAsync(Guid id, Guid userId);

    /// <summary>
    /// Add a track to a playlist
    /// </summary>
    Task<bool> AddTrackToPlaylistAsync(Guid playlistId, Guid trackId, Guid userId);

    /// <summary>
    /// Remove a track from a playlist
    /// </summary>
    Task<bool> RemoveTrackFromPlaylistAsync(Guid playlistId, Guid trackId, Guid userId);

    /// <summary>
    /// Reorder tracks in a playlist
    /// </summary>
    Task<bool> ReorderTracksAsync(Guid playlistId, Guid userId, List<Guid> trackIds);
}
