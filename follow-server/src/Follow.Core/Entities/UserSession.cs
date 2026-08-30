namespace Follow.Core.Entities;

public class UserSession : BaseEntity
{
    public Guid UserId { get; set; }
    public required byte[] RefreshTokenHash { get; set; }
    public byte[]? PreviousRefreshTokenHash { get; set; }
    public DateTime LastUsedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; }
    public DateTime? RotatedAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public string? RevokedReason { get; set; }
    public string? DeviceName { get; set; }
    public required string ClientType { get; set; }
    public string? UserAgent { get; set; }
    public int Version { get; set; }

    public User User { get; set; } = null!;
}
