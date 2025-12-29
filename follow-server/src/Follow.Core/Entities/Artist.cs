namespace Follow.Core.Entities;

/// <summary>
/// Artist entity
/// </summary>
public class Artist : BaseEntity
{
    public required string Name { get; set; }
    public string? CoverUrl { get; set; }
    public string? Bio { get; set; }

    // Navigation properties
    public ICollection<Track> Tracks { get; set; } = [];
    public ICollection<Album> Albums { get; set; } = [];
}
