namespace Follow.Core.Entities;

/// <summary>
/// Join table for Track and Tag many-to-many relationship
/// </summary>
public class TrackTag : BaseEntity
{
    public Guid TrackId { get; set; }
    public Guid TagId { get; set; }

    // Navigation properties
    public Track Track { get; set; } = null!;
    public Tag Tag { get; set; } = null!;
}
