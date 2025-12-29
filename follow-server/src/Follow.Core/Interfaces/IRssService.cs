using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for RSS subscription management
/// </summary>
public interface IRssService
{
    Task<List<RssSubscriptionDto>> GetSubscriptionsAsync(Guid userId);
    Task<RssSubscriptionDto?> GetSubscriptionByIdAsync(Guid id, Guid userId);
    Task<RssSubscriptionDto> AddSubscriptionAsync(Guid userId, AddRssSubscriptionRequest request);
    Task<bool> RemoveSubscriptionAsync(Guid id, Guid userId);
    Task<RssSubscriptionDto?> RefreshSubscriptionAsync(Guid id, Guid userId);
    Task<List<RssEpisodeDto>> GetEpisodesAsync(Guid subscriptionId, Guid userId, int page = 1, int pageSize = 50);
    Task<bool> MarkEpisodePlayedAsync(Guid episodeId, Guid userId);
}

public record RssSubscriptionDto(
    Guid Id,
    string FeedUrl,
    string? Title,
    string? Description,
    string? CoverUrl,
    int EpisodeCount,
    DateTime? LastFetchedAt,
    DateTime CreatedAt
);

public record RssEpisodeDto(
    Guid Id,
    string Title,
    string? Description,
    string AudioUrl,
    int DurationSeconds,
    DateTime? PublishedAt,
    bool IsPlayed
);

public record AddRssSubscriptionRequest(string FeedUrl);
