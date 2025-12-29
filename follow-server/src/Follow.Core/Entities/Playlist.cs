namespace Follow.Core.Entities;

/// <summary>
/// Playlist entity
/// </summary>
public class Playlist : BaseEntity
{
    public required string Name { get; set; }
    public string? Description { get; set; }
    public string? CoverUrl { get; set; }
    public bool IsPublic { get; set; }
    
    // Foreign key
    public Guid UserId { get; set; }

    // Navigation properties
    public User User { get; set; } = null!;
    public ICollection<PlaylistTrack> PlaylistTracks { get; set; } = [];
}
