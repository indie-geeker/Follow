namespace Follow.Core.Entities;

/// <summary>
/// Tag for categorizing tracks (e.g., "流行", "K歌", "周杰伦")
/// </summary>
public class Tag : BaseEntity
{
    /// <summary>
    /// Tag name (e.g., "流行", "经典", "K歌必唱")
    /// </summary>
    public required string Name { get; set; }
    
    /// <summary>
    /// Tag category (e.g., "风格", "榜单", "场景", "艺术家")
    /// </summary>
    public string? Category { get; set; }
    
    /// <summary>
    /// Cover image URL for the tag
    /// </summary>
    public string? CoverUrl { get; set; }

    // Navigation properties
    public ICollection<TrackTag> TrackTags { get; set; } = [];
}
