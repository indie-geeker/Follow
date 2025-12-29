using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Admin service for user management and dashboard stats
/// </summary>
public class AdminService : IAdminService
{
    private readonly FollowDbContext _context;

    public AdminService(FollowDbContext context)
    {
        _context = context;
    }

    public async Task<(List<AdminUserDto> Users, int TotalCount)> GetUsersAsync(int page = 1, int pageSize = 20, string? search = null)
    {
        var query = _context.Users.AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var searchLower = search.ToLower();
            query = query.Where(u => 
                u.Username.ToLower().Contains(searchLower) ||
                u.Email.ToLower().Contains(searchLower));
        }

        var totalCount = await query.CountAsync();

        var users = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(u => new AdminUserDto(
                u.Id,
                u.Username,
                u.Email,
                u.Role.ToString(),
                u.AvatarUrl,
                u.CreatedAt,
                u.Playlists.Count,
                u.Favorites.Count
            ))
            .ToListAsync();

        return (users, totalCount);
    }

    public async Task<AdminUserDto?> GetUserByIdAsync(Guid id)
    {
        var user = await _context.Users
            .Include(u => u.Playlists)
            .Include(u => u.Favorites)
            .FirstOrDefaultAsync(u => u.Id == id);

        if (user == null) return null;

        return new AdminUserDto(
            user.Id,
            user.Username,
            user.Email,
            user.Role.ToString(),
            user.AvatarUrl,
            user.CreatedAt,
            user.Playlists.Count,
            user.Favorites.Count
        );
    }

    public async Task<AdminUserDto?> UpdateUserRoleAsync(Guid id, UserRole role)
    {
        var user = await _context.Users
            .Include(u => u.Playlists)
            .Include(u => u.Favorites)
            .FirstOrDefaultAsync(u => u.Id == id);

        if (user == null) return null;

        user.Role = role;
        await _context.SaveChangesAsync();

        return new AdminUserDto(
            user.Id,
            user.Username,
            user.Email,
            user.Role.ToString(),
            user.AvatarUrl,
            user.CreatedAt,
            user.Playlists.Count,
            user.Favorites.Count
        );
    }

    public async Task<bool> DeleteUserAsync(Guid id)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null) return false;

        // Prevent deleting the last admin
        if (user.Role == UserRole.Admin)
        {
            var adminCount = await _context.Users.CountAsync(u => u.Role == UserRole.Admin);
            if (adminCount <= 1) return false;
        }

        _context.Users.Remove(user);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<DashboardStatsDto> GetDashboardStatsAsync()
    {
        var stats = new DashboardStatsDto(
            TotalUsers: await _context.Users.CountAsync(),
            TotalTracks: await _context.Tracks.CountAsync(),
            TotalArtists: await _context.Artists.CountAsync(),
            TotalAlbums: await _context.Albums.CountAsync(),
            TotalPlaylists: await _context.Playlists.CountAsync()
        );

        return stats;
    }
}
