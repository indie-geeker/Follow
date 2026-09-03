namespace Follow.Shared.DTOs;

public record RegisterRequest(
    string Username,
    string Email,
    string Password,
    string TokenTransport = "body",
    string? DeviceName = null);

public record CreateUserRequest(string Username, string Email, string Password, string Role);

public record LoginRequest(
    string Identifier,
    string Password,
    string TokenTransport = "body",
    string? DeviceName = null);

public record RefreshTokenRequest(
    string? RefreshToken = null,
    string TokenTransport = "body");

public record AuthResponse(
    string? AccessToken,
    string? RefreshToken,
    Guid SessionId,
    DateTime ExpiresAt,
    UserDto User);

public record UserDto(
    Guid Id,
    string Username,
    string Email,
    string Role,
    string? AvatarUrl,
    DateTime CreatedAt
);
