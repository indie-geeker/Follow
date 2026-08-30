using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace Follow.Infrastructure.Services;

/// <summary>
/// JWT token generation and validation service
/// </summary>
public class JwtService : IJwtService
{
    private readonly IConfiguration _configuration;
    private readonly string _secretKey;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _accessTokenExpirationMinutes;

    public JwtService(IConfiguration configuration)
    {
        _configuration = configuration;
        var jwtSettings = _configuration.GetSection("JwtSettings");
        _secretKey = jwtSettings["SecretKey"] ?? throw new InvalidOperationException("JWT SecretKey not configured");
        _issuer = jwtSettings["Issuer"] ?? "FollowMusicApi";
        _audience = jwtSettings["Audience"] ?? "FollowMusicClient";
        _accessTokenExpirationMinutes = int.Parse(jwtSettings["AccessTokenExpirationMinutes"] ?? "60");
    }

    public string GenerateAccessToken(User user, Guid sessionId)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.Username),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, user.Role.ToString()),
            new("jti", Guid.NewGuid().ToString()),
            new("sid", sessionId.ToString())
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_secretKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_accessTokenExpirationMinutes),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

}
