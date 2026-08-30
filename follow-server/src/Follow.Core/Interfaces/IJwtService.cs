using Follow.Core.Entities;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for JWT token generation
/// </summary>
public interface IJwtService
{
    string GenerateAccessToken(User user, Guid sessionId);
}
