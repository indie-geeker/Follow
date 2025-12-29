using Follow.Core.Entities;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for JWT token generation
/// </summary>
public interface IJwtService
{
    string GenerateAccessToken(User user);
    string GenerateRefreshToken();
    (bool isValid, Guid userId) ValidateRefreshToken(string refreshToken);
}
