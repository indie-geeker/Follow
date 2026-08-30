using Follow.Core.Entities;
using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for authentication service
/// </summary>
public interface IAuthService
{
    Task<AuthResponse> RegisterAsync(RegisterRequest request, string? userAgent = null);
    Task<AuthResponse> LoginAsync(LoginRequest request, string? userAgent = null);
    Task<AuthResponse> RefreshTokenAsync(RefreshTokenRequest request);
    Task<bool> LogoutAsync(Guid userId, Guid sessionId);
    Task LogoutAllAsync(Guid userId);
    Task<List<SessionDto>> GetSessionsAsync(Guid userId, Guid currentSessionId);
    Task<bool> RevokeSessionAsync(Guid userId, Guid sessionId);
    Task<bool> IsSessionActiveAsync(Guid userId, Guid sessionId);
    Task<User?> GetUserByIdAsync(Guid userId);
}
