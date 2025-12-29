namespace Follow.Core.Entities;

/// <summary>
/// User's favorite track
/// </summary>
public class Favorite : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid TrackId { get; set; }

    // Navigation properties
    public User User { get; set; } = null!;
    public Track Track { get; set; } = null!;
}
