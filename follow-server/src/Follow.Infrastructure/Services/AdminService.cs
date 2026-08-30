using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Admin service for user management and dashboard stats
/// </summary>
public class AdminService : IAdminService
{
    private readonly FollowDbContext _context;
    private readonly IPasswordHasher _passwordHasher;

    public AdminService(FollowDbContext context, IPasswordHasher passwordHasher)
    {
        _context = context;
        _passwordHasher = passwordHasher;
    }

    public async Task<AdminUserDto> CreateUserAsync(CreateUserRequest request)
    {
        var credentials = UserCredentialPolicy.NormalizeAndValidate(
            request.Username,
            request.Email,
            request.Password);

        var role = request.Role switch
        {
            var value when string.Equals(value, nameof(UserRole.Member), StringComparison.OrdinalIgnoreCase) => UserRole.Member,
            var value when string.Equals(value, nameof(UserRole.Admin), StringComparison.OrdinalIgnoreCase) => UserRole.Admin,
            _ => throw new ArgumentException("角色必须为 Member 或 Admin")
        };

        if (await _context.Users.AnyAsync(user => user.Email == credentials.Email))
        {
            throw new InvalidOperationException("该邮箱已被注册");
        }

        if (await _context.Users.AnyAsync(user => user.Username == credentials.Username))
        {
            throw new InvalidOperationException("该用户名已被使用");
        }

        var user = new User
        {
            Username = credentials.Username,
            Email = credentials.Email,
            PasswordHash = _passwordHasher.HashPassword(credentials.Password),
            Role = role
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return ToAdminUserDto(user);
    }

    public async Task<(List<AdminUserDto> Users, int TotalCount)> GetUsersAsync(int page = 1, int pageSize = 20, string? search = null)
    {
        var offset = PaginationPolicy.GetOffset(page, pageSize);
        var query = _context.Users.AsNoTracking().AsQueryable();

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
            .ThenBy(u => u.Id)
            .Skip(offset)
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
            .Include(u => u.Sessions)
            .FirstOrDefaultAsync(u => u.Id == id);

        if (user == null) return null;

        if (user.Role == role) return ToAdminUserDto(user);
        if (user.Role == UserRole.Admin && role != UserRole.Admin)
        {
            var adminCount = await _context.Users.CountAsync(item =>
                item.Role == UserRole.Admin);
            if (adminCount <= 1)
                throw new InvalidOperationException("不能降级最后一个管理员");
        }

        user.Role = role;
        var now = DateTime.UtcNow;
        foreach (var session in user.Sessions.Where(item => item.RevokedAt == null))
        {
            session.RevokedAt = now;
            session.RevokedReason = "role-changed";
            session.Version++;
        }
        await _context.SaveChangesAsync();

        return ToAdminUserDto(user);
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

    private static AdminUserDto ToAdminUserDto(User user) => new(
        user.Id,
        user.Username,
        user.Email,
        user.Role.ToString(),
        user.AvatarUrl,
        user.CreatedAt,
        user.Playlists.Count,
        user.Favorites.Count);
}
