using Follow.Core.Entities;
using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for admin user management
/// </summary>
public interface IAdminService
{
    Task<AdminUserDto> CreateUserAsync(CreateUserRequest request);
    Task<(List<AdminUserDto> Users, int TotalCount)> GetUsersAsync(int page = 1, int pageSize = 20, string? search = null);
    Task<AdminUserDto?> GetUserByIdAsync(Guid id);
    Task<AdminUserDto?> UpdateUserRoleAsync(Guid id, UserRole role);
    Task<bool> DeleteUserAsync(Guid id);
    Task<DashboardStatsDto> GetDashboardStatsAsync();
}

public record AdminUserDto(
    Guid Id,
    string Username,
    string Email,
    string Role,
    string? AvatarUrl,
    DateTime CreatedAt,
    int PlaylistCount,
    int FavoriteCount
);

public record DashboardStatsDto(
    int TotalUsers,
    int TotalTracks,
    int TotalArtists,
    int TotalAlbums,
    int TotalPlaylists
);
