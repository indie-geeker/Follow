namespace Follow.Core.Entities;

/// <summary>
/// Join table for Playlist and Track many-to-many relationship
/// </summary>
public class PlaylistTrack : BaseEntity
{
    public Guid PlaylistId { get; set; }
    public Guid TrackId { get; set; }
    public int Position { get; set; }

    // Navigation properties
    public Playlist Playlist { get; set; } = null!;
    public Track Track { get; set; } = null!;
}
