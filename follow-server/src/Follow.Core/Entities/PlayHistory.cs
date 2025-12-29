namespace Follow.Core.Entities;

/// <summary>
/// Play history record
/// </summary>
public class PlayHistory : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid TrackId { get; set; }
    public DateTime PlayedAt { get; set; } = DateTime.UtcNow;
    public int PlayDurationSeconds { get; set; }

    // Navigation properties
    public User User { get; set; } = null!;
    public Track Track { get; set; } = null!;
}
