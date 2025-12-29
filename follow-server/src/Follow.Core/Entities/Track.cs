namespace Follow.Core.Entities;

/// <summary>
/// Music track entity
/// </summary>
public class Track : BaseEntity
{
    public required string Title { get; set; }
    public int DurationSeconds { get; set; }
    public required string FilePath { get; set; }
    public string? CoverUrl { get; set; }
    public string? LyricsUrl { get; set; }
    public int BitRate { get; set; }
    public string? Format { get; set; }
    
    // Foreign keys
    public Guid? ArtistId { get; set; }
    public Guid? AlbumId { get; set; }

    // Navigation properties
    public Artist? Artist { get; set; }
    public Album? Album { get; set; }
    public ICollection<PlaylistTrack> PlaylistTracks { get; set; } = [];
    public ICollection<PlayHistory> PlayHistories { get; set; } = [];
    public ICollection<Favorite> Favorites { get; set; } = [];
}
