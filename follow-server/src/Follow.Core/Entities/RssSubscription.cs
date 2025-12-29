namespace Follow.Core.Entities;

/// <summary>
/// RSS subscription for podcast feeds
/// </summary>
public class RssSubscription : BaseEntity
{
    public required string FeedUrl { get; set; }
    public string? Title { get; set; }
    public string? Description { get; set; }
    public string? CoverUrl { get; set; }
    public DateTime? LastFetchedAt { get; set; }
    
    // Foreign key
    public Guid UserId { get; set; }

    // Navigation properties
    public User User { get; set; } = null!;
    public ICollection<RssEpisode> Episodes { get; set; } = [];
}
