using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Authentication service implementation
/// </summary>
public class AuthService : IAuthService
{
    private readonly FollowDbContext _context;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtService _jwtService;
    private readonly int _refreshTokenExpirationDays;

    public AuthService(
        FollowDbContext context,
        IPasswordHasher passwordHasher,
        IJwtService jwtService,
        IConfiguration configuration)
    {
        _context = context;
        _passwordHasher = passwordHasher;
        _jwtService = jwtService;
        _refreshTokenExpirationDays = int.Parse(
            configuration.GetSection("JwtSettings")["RefreshTokenExpirationDays"] ?? "7");
    }

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request)
    {
        // Check if user already exists
        if (await _context.Users.AnyAsync(u => u.Email == request.Email))
        {
            throw new InvalidOperationException("User with this email already exists");
        }

        if (await _context.Users.AnyAsync(u => u.Username == request.Username))
        {
            throw new InvalidOperationException("Username already taken");
        }

        // Determine role: first user is Admin, others are Member
        var isFirstUser = !await _context.Users.AnyAsync();
        var role = isFirstUser ? UserRole.Admin : UserRole.Member;

        // Create new user
        var user = new User
        {
            Username = request.Username,
            Email = request.Email,
            PasswordHash = _passwordHasher.HashPassword(request.Password),
            Role = role,
            RefreshToken = _jwtService.GenerateRefreshToken(),
            RefreshTokenExpiryTime = DateTime.UtcNow.AddDays(_refreshTokenExpirationDays)
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return CreateAuthResponse(user);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);

        if (user == null || !_passwordHasher.VerifyPassword(request.Password, user.PasswordHash))
        {
            throw new UnauthorizedAccessException("邮箱或密码错误");
        }

        // Update refresh token
        user.RefreshToken = _jwtService.GenerateRefreshToken();
        user.RefreshTokenExpiryTime = DateTime.UtcNow.AddDays(_refreshTokenExpirationDays);
        await _context.SaveChangesAsync();

        return CreateAuthResponse(user);
    }

    public async Task<AuthResponse> RefreshTokenAsync(RefreshTokenRequest request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(
            u => u.RefreshToken == request.RefreshToken &&
                 u.RefreshTokenExpiryTime > DateTime.UtcNow);

        if (user == null)
        {
            throw new UnauthorizedAccessException("无效或过期的刷新令牌");
        }

        // Generate new tokens
        user.RefreshToken = _jwtService.GenerateRefreshToken();
        user.RefreshTokenExpiryTime = DateTime.UtcNow.AddDays(_refreshTokenExpirationDays);
        await _context.SaveChangesAsync();

        return CreateAuthResponse(user);
    }

    public async Task<bool> LogoutAsync(Guid userId)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null) return false;

        user.RefreshToken = null;
        user.RefreshTokenExpiryTime = null;
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<User?> GetUserByIdAsync(Guid userId)
    {
        return await _context.Users.FindAsync(userId);
    }

    private AuthResponse CreateAuthResponse(User user)
    {
        var accessToken = _jwtService.GenerateAccessToken(user);
        var userDto = new UserDto(
            user.Id,
            user.Username,
            user.Email,
            user.Role.ToString(),
            user.AvatarUrl,
            user.CreatedAt);

        return new AuthResponse(accessToken, user.RefreshToken!, userDto);
    }
}
