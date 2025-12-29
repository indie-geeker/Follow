namespace Follow.Shared.DTOs;

public record RegisterRequest(string Username, string Email, string Password);

public record LoginRequest(string Email, string Password);

public record RefreshTokenRequest(string RefreshToken);

public record AuthResponse(string AccessToken, string RefreshToken, UserDto User);

public record UserDto(
    Guid Id,
    string Username,
    string Email,
    string Role,
    string? AvatarUrl,
    DateTime CreatedAt
);
