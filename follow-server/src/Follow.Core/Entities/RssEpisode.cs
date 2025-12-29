namespace Follow.Core.Entities;

/// <summary>
/// RSS episode from a subscription
/// </summary>
public class RssEpisode : BaseEntity
{
    public required string Title { get; set; }
    public string? Description { get; set; }
    public required string AudioUrl { get; set; }
    public int DurationSeconds { get; set; }
    public DateTime? PublishedAt { get; set; }
    public bool IsPlayed { get; set; }
    
    // Foreign key
    public Guid SubscriptionId { get; set; }

    // Navigation properties
    public RssSubscription Subscription { get; set; } = null!;
}
