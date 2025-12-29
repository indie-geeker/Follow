using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Follow.Infrastructure.Services;

/// <summary>
/// RSS subscription service for podcast feeds
/// </summary>
public class RssService : IRssService
{
    private readonly FollowDbContext _context;
    private readonly ILogger<RssService> _logger;

    public RssService(FollowDbContext context, ILogger<RssService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<List<RssSubscriptionDto>> GetSubscriptionsAsync(Guid userId)
    {
        var subscriptions = await _context.RssSubscriptions
            .Where(s => s.UserId == userId)
            .Include(s => s.Episodes)
            .OrderByDescending(s => s.CreatedAt)
            .ToListAsync();

        return subscriptions.Select(s => new RssSubscriptionDto(
            s.Id,
            s.FeedUrl,
            s.Title,
            s.Description,
            s.CoverUrl,
            s.Episodes.Count,
            s.LastFetchedAt,
            s.CreatedAt
        )).ToList();
    }

    public async Task<RssSubscriptionDto?> GetSubscriptionByIdAsync(Guid id, Guid userId)
    {
        var subscription = await _context.RssSubscriptions
            .Include(s => s.Episodes)
            .FirstOrDefaultAsync(s => s.Id == id && s.UserId == userId);

        if (subscription == null) return null;

        return new RssSubscriptionDto(
            subscription.Id,
            subscription.FeedUrl,
            subscription.Title,
            subscription.Description,
            subscription.CoverUrl,
            subscription.Episodes.Count,
            subscription.LastFetchedAt,
            subscription.CreatedAt
        );
    }

    public async Task<RssSubscriptionDto> AddSubscriptionAsync(Guid userId, AddRssSubscriptionRequest request)
    {
        // Check if already subscribed
        var existing = await _context.RssSubscriptions
            .FirstOrDefaultAsync(s => s.UserId == userId && s.FeedUrl == request.FeedUrl);

        if (existing != null)
        {
            return new RssSubscriptionDto(
                existing.Id,
                existing.FeedUrl,
                existing.Title,
                existing.Description,
                existing.CoverUrl,
                0,
                existing.LastFetchedAt,
                existing.CreatedAt
            );
        }

        var subscription = new RssSubscription
        {
            UserId = userId,
            FeedUrl = request.FeedUrl,
            Title = "New Subscription", // Will be updated when fetched
        };

        _context.RssSubscriptions.Add(subscription);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Added RSS subscription: {FeedUrl} for user {UserId}", request.FeedUrl, userId);

        return new RssSubscriptionDto(
            subscription.Id,
            subscription.FeedUrl,
            subscription.Title,
            subscription.Description,
            subscription.CoverUrl,
            0,
            subscription.LastFetchedAt,
            subscription.CreatedAt
        );
    }

    public async Task<bool> RemoveSubscriptionAsync(Guid id, Guid userId)
    {
        var subscription = await _context.RssSubscriptions
            .FirstOrDefaultAsync(s => s.Id == id && s.UserId == userId);

        if (subscription == null) return false;

        _context.RssSubscriptions.Remove(subscription);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<RssSubscriptionDto?> RefreshSubscriptionAsync(Guid id, Guid userId)
    {
        var subscription = await _context.RssSubscriptions
            .Include(s => s.Episodes)
            .FirstOrDefaultAsync(s => s.Id == id && s.UserId == userId);

        if (subscription == null) return null;

        // TODO: Implement actual RSS feed parsing here
        // For now, just update the last fetched time
        subscription.LastFetchedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Refreshed RSS subscription: {SubscriptionId}", id);

        return new RssSubscriptionDto(
            subscription.Id,
            subscription.FeedUrl,
            subscription.Title,
            subscription.Description,
            subscription.CoverUrl,
            subscription.Episodes.Count,
            subscription.LastFetchedAt,
            subscription.CreatedAt
        );
    }

    public async Task<List<RssEpisodeDto>> GetEpisodesAsync(Guid subscriptionId, Guid userId, int page = 1, int pageSize = 50)
    {
        var subscription = await _context.RssSubscriptions
            .FirstOrDefaultAsync(s => s.Id == subscriptionId && s.UserId == userId);

        if (subscription == null) return [];

        var episodes = await _context.RssEpisodes
            .Where(e => e.SubscriptionId == subscriptionId)
            .OrderByDescending(e => e.PublishedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return episodes.Select(e => new RssEpisodeDto(
            e.Id,
            e.Title,
            e.Description,
            e.AudioUrl,
            e.DurationSeconds,
            e.PublishedAt,
            e.IsPlayed
        )).ToList();
    }

    public async Task<bool> MarkEpisodePlayedAsync(Guid episodeId, Guid userId)
    {
        var episode = await _context.RssEpisodes
            .Include(e => e.Subscription)
            .FirstOrDefaultAsync(e => e.Id == episodeId && e.Subscription.UserId == userId);

        if (episode == null) return false;

        episode.IsPlayed = true;
        await _context.SaveChangesAsync();

        return true;
    }
}
