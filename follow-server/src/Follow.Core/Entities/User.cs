namespace Follow.Core.Entities;

/// <summary>
/// User entity for family multi-user support
/// </summary>
public class User : BaseEntity
{
    public required string Username { get; set; }
    public required string Email { get; set; }
    public required string PasswordHash { get; set; }
    public UserRole Role { get; set; } = UserRole.Member;
    public string? AvatarUrl { get; set; }

    // Navigation properties
    public ICollection<Playlist> Playlists { get; set; } = [];
    public ICollection<PlayHistory> PlayHistories { get; set; } = [];
    public ICollection<Favorite> Favorites { get; set; } = [];
    public ICollection<UserSession> Sessions { get; set; } = [];
}

/// <summary>
/// User roles for family multi-user system
/// </summary>
public enum UserRole
{
    /// <summary>
    /// Admin can upload, delete music, manage users
    /// </summary>
    Admin,
    
    /// <summary>
    /// Member can play, favorite, create personal playlists
    /// </summary>
    Member
}
