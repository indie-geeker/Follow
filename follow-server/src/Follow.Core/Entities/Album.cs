namespace Follow.Core.Entities;

/// <summary>
/// Album entity
/// </summary>
public class Album : BaseEntity
{
    public required string Title { get; set; }
    public int? Year { get; set; }
    public string? CoverUrl { get; set; }
    
    // Foreign key
    public Guid? ArtistId { get; set; }

    // Navigation properties
    public Artist? Artist { get; set; }
    public ICollection<Track> Tracks { get; set; } = [];
}
