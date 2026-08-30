namespace Follow.Shared.DTOs;

public record SessionDto(
    Guid Id,
    string? DeviceName,
    string ClientType,
    DateTime CreatedAt,
    DateTime LastUsedAt,
    DateTime ExpiresAt,
    bool IsCurrent);
