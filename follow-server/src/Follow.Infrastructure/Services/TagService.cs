using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Tag management service implementation
/// </summary>
public class TagService : ITagService
{
    private readonly FollowDbContext _context;

    public TagService(FollowDbContext context)
    {
        _context = context;
    }

    public async Task<List<TagDto>> GetTagsAsync(string? category = null)
    {
        var query = _context.Tags.AsQueryable();
        
        if (!string.IsNullOrEmpty(category))
        {
            query = query.Where(t => t.Category == category);
        }

        return await query
            .OrderBy(t => t.Category)
            .ThenBy(t => t.Name)
            .Select(t => new TagDto(
                t.Id,
                t.Name,
                t.Category,
                t.CoverUrl,
                t.TrackTags.Count,
                t.CreatedAt
            ))
            .ToListAsync();
    }

    public async Task<TagDto?> GetTagByIdAsync(Guid id)
    {
        return await _context.Tags
            .Where(t => t.Id == id)
            .Select(t => new TagDto(
                t.Id,
                t.Name,
                t.Category,
                t.CoverUrl,
                t.TrackTags.Count,
                t.CreatedAt
            ))
            .FirstOrDefaultAsync();
    }

    public async Task<TagDto> CreateTagAsync(CreateTagRequest request)
    {
        var tag = new Tag
        {
            Name = request.Name,
            Category = request.Category,
            CoverUrl = request.CoverUrl
        };

        _context.Tags.Add(tag);
        await _context.SaveChangesAsync();

        return new TagDto(
            tag.Id,
            tag.Name,
            tag.Category,
            tag.CoverUrl,
            0,
            tag.CreatedAt
        );
    }

    public async Task<TagDto?> UpdateTagAsync(Guid id, UpdateTagRequest request)
    {
        var tag = await _context.Tags.FindAsync(id);
        if (tag == null) return null;

        tag.Name = request.Name;
        tag.Category = request.Category;
        tag.CoverUrl = request.CoverUrl;

        await _context.SaveChangesAsync();

        var trackCount = await _context.TrackTags.CountAsync(tt => tt.TagId == id);

        return new TagDto(
            tag.Id,
            tag.Name,
            tag.Category,
            tag.CoverUrl,
            trackCount,
            tag.CreatedAt
        );
    }

    public async Task<bool> DeleteTagAsync(Guid id)
    {
        var tag = await _context.Tags.FindAsync(id);
        if (tag == null) return false;

        _context.Tags.Remove(tag);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<(List<TrackDto> Tracks, int TotalCount)> GetTracksByTagAsync(Guid tagId, int page = 1, int pageSize = 20)
    {
        var query = _context.TrackTags
            .Where(tt => tt.TagId == tagId)
            .Select(tt => tt.Track)
            .Include(t => t.Artist)
            .Include(t => t.Album);

        var totalCount = await query.CountAsync();

        var tracks = await query
            .OrderByDescending(t => t.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(t => new TrackDto(
                t.Id,
                t.Title,
                t.DurationSeconds,
                t.CoverUrl,
                t.LyricsUrl,
                t.BitRate,
                t.Format,
                t.Artist != null ? new ArtistDto(t.Artist.Id, t.Artist.Name, t.Artist.CoverUrl, t.Artist.Bio) : null,
                t.Album != null ? new AlbumDto(
                    t.Album.Id, 
                    t.Album.Title, 
                    t.Album.Year, 
                    t.Album.CoverUrl,
                    t.Album.Artist != null ? new ArtistDto(t.Album.Artist.Id, t.Album.Artist.Name, t.Album.Artist.CoverUrl, t.Album.Artist.Bio) : null
                ) : null,
                t.CreatedAt
            ))
            .ToListAsync();

        return (tracks, totalCount);
    }
}
