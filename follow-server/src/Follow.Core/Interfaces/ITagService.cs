using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for tag management service
/// </summary>
public interface ITagService
{
    /// <summary>
    /// Get all tags, optionally filtered by category
    /// </summary>
    Task<List<TagDto>> GetTagsAsync(string? category = null);

    /// <summary>
    /// Get a tag by ID
    /// </summary>
    Task<TagDto?> GetTagByIdAsync(Guid id);

    /// <summary>
    /// Create a new tag
    /// </summary>
    Task<TagDto> CreateTagAsync(CreateTagRequest request);

    /// <summary>
    /// Update an existing tag
    /// </summary>
    Task<TagDto?> UpdateTagAsync(Guid id, UpdateTagRequest request);

    /// <summary>
    /// Delete a tag
    /// </summary>
    Task<bool> DeleteTagAsync(Guid id);

    /// <summary>
    /// Get tracks associated with a tag
    /// </summary>
    Task<(List<TrackDto> Tracks, int TotalCount)> GetTracksByTagAsync(Guid tagId, int page = 1, int pageSize = 20);
}

public record TagDto(
    Guid Id,
    string Name,
    string? Category,
    string? CoverUrl,
    int TrackCount,
    DateTime CreatedAt
);

public record CreateTagRequest(string Name, string? Category, string? CoverUrl);
public record UpdateTagRequest(string Name, string? Category, string? CoverUrl);
