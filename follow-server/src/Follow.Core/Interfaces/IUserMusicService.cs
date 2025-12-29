using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for user favorites and history
/// </summary>
public interface IUserMusicService
{
    // Favorites
    Task<List<TrackDto>> GetFavoritesAsync(Guid userId);
    Task<bool> AddToFavoritesAsync(Guid userId, Guid trackId);
    Task<bool> RemoveFromFavoritesAsync(Guid userId, Guid trackId);
    Task<bool> IsFavoriteAsync(Guid userId, Guid trackId);

    // Play History
    Task<List<PlayHistoryItemDto>> GetPlayHistoryAsync(Guid userId, int limit = 50);
    Task AddToPlayHistoryAsync(Guid userId, Guid trackId, int playDurationSeconds);
}

public record PlayHistoryItemDto(
    Guid TrackId,
    string TrackTitle,
    ArtistDto? Artist,
    DateTime PlayedAt,
    int PlayDurationSeconds
);
