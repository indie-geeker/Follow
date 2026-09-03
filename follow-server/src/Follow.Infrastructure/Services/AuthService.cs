using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Follow.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly FollowDbContext _context;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtService _jwtService;
    private readonly RefreshTokenProtector _refreshTokenProtector;
    private readonly int _refreshTokenExpirationDays;

    public AuthService(
        FollowDbContext context,
        IPasswordHasher passwordHasher,
        IJwtService jwtService,
        RefreshTokenProtector refreshTokenProtector,
        IConfiguration configuration)
    {
        _context = context;
        _passwordHasher = passwordHasher;
        _jwtService = jwtService;
        _refreshTokenProtector = refreshTokenProtector;
        _refreshTokenExpirationDays = int.Parse(
            configuration.GetSection("JwtSettings")["RefreshTokenExpirationDays"] ?? "7");
    }

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, string? userAgent = null)
    {
        var credentials = UserCredentialPolicy.NormalizeAndValidate(
            request.Username,
            request.Email,
            request.Password);

        if (await _context.Users.AnyAsync(u => u.Email == credentials.Email))
            throw new InvalidOperationException("User with this email already exists");
        if (await _context.Users.AnyAsync(u => u.Username == credentials.Username))
            throw new InvalidOperationException("Username already taken");

        var user = new User
        {
            Username = credentials.Username,
            Email = credentials.Email,
            PasswordHash = _passwordHasher.HashPassword(credentials.Password),
            Role = UserRole.Member
        };

        _context.Users.Add(user);
        return await CreateSessionAsync(
            user,
            request.TokenTransport,
            request.DeviceName,
            userAgent);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, string? userAgent = null)
    {
        var normalizedIdentifier = UserCredentialPolicy.NormalizeLoginIdentifier(request.Identifier);
        if (normalizedIdentifier.Length == 0)
            throw new ArgumentException("请输入用户名或邮箱");

        var user = await _context.Users.FirstOrDefaultAsync(u =>
            u.Username == normalizedIdentifier || u.Email == normalizedIdentifier);

        if (user == null || !_passwordHasher.VerifyPassword(request.Password, user.PasswordHash))
            throw new UnauthorizedAccessException("用户名/邮箱或密码错误");

        return await CreateSessionAsync(
            user,
            request.TokenTransport,
            request.DeviceName,
            userAgent);
    }

    public async Task<AuthResponse> RefreshTokenAsync(RefreshTokenRequest request)
    {
        if (!_refreshTokenProtector.TryRead(request.RefreshToken, out var sessionId, out var presentedHash))
            throw new UnauthorizedAccessException("无效或过期的刷新令牌");

        var session = await _context.UserSessions
            .Include(item => item.User)
            .FirstOrDefaultAsync(item => item.Id == sessionId);

        if (session == null || session.RevokedAt != null || session.ExpiresAt <= DateTime.UtcNow)
            throw new UnauthorizedAccessException("无效或过期的刷新令牌");

        if (!RefreshTokenProtector.Matches(session.RefreshTokenHash, presentedHash))
        {
            if (session.PreviousRefreshTokenHash != null &&
                RefreshTokenProtector.Matches(session.PreviousRefreshTokenHash, presentedHash))
            {
                session.RevokedAt = DateTime.UtcNow;
                session.RevokedReason = "refresh-token-reuse";
                session.Version++;
                try
                {
                    await _context.SaveChangesAsync();
                }
                catch (DbUpdateConcurrencyException exception)
                {
                    throw new InvalidOperationException("会话状态已变更", exception);
                }

                throw new UnauthorizedAccessException("检测到刷新令牌重放，会话已撤销");
            }

            throw new UnauthorizedAccessException("无效或过期的刷新令牌");
        }

        var issued = _refreshTokenProtector.Issue(session.Id);
        var now = DateTime.UtcNow;
        session.PreviousRefreshTokenHash = session.RefreshTokenHash;
        session.RefreshTokenHash = issued.Hash;
        session.LastUsedAt = now;
        session.RotatedAt = now;
        session.ExpiresAt = now.AddDays(_refreshTokenExpirationDays);
        session.Version++;
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException exception)
        {
            throw new InvalidOperationException("刷新令牌已轮换", exception);
        }

        return CreateAuthResponse(session.User, session, issued.Token);
    }

    public async Task<bool> LogoutAsync(Guid userId, Guid sessionId) =>
        await RevokeSessionAsync(userId, sessionId);

    public async Task LogoutAllAsync(Guid userId)
    {
        var now = DateTime.UtcNow;
        if (_context.Database.IsRelational())
        {
            await _context.UserSessions
                .Where(session => session.UserId == userId && session.RevokedAt == null)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(session => session.RevokedAt, now)
                    .SetProperty(session => session.RevokedReason, "logout-all")
                    .SetProperty(session => session.UpdatedAt, now)
                    .SetProperty(session => session.Version, session => session.Version + 1));
            return;
        }

        for (var attempt = 0; attempt < 3; attempt++)
        {
            var sessions = await _context.UserSessions
                .Where(session => session.UserId == userId && session.RevokedAt == null)
                .ToListAsync();
            if (sessions.Count == 0) return;

            foreach (var session in sessions)
            {
                session.RevokedAt = now;
                session.RevokedReason = "logout-all";
                session.Version++;
            }

            try
            {
                await _context.SaveChangesAsync();
                return;
            }
            catch (DbUpdateConcurrencyException) when (attempt < 2)
            {
                DetachTrackedSessions();
            }
        }
    }

    public async Task<List<SessionDto>> GetSessionsAsync(Guid userId, Guid currentSessionId)
    {
        return await _context.UserSessions
            .AsNoTracking()
            .Where(session => session.UserId == userId &&
                              session.RevokedAt == null &&
                              session.ExpiresAt > DateTime.UtcNow)
            .OrderByDescending(session => session.LastUsedAt)
            .ThenBy(session => session.Id)
            .Select(session => new SessionDto(
                session.Id,
                session.DeviceName,
                session.ClientType,
                session.CreatedAt,
                session.LastUsedAt,
                session.ExpiresAt,
                session.Id == currentSessionId))
            .ToListAsync();
    }

    public async Task<bool> RevokeSessionAsync(Guid userId, Guid sessionId)
    {
        var now = DateTime.UtcNow;
        if (_context.Database.IsRelational())
        {
            var updated = await _context.UserSessions
                .Where(session => session.Id == sessionId &&
                                  session.UserId == userId &&
                                  session.RevokedAt == null)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(session => session.RevokedAt, now)
                    .SetProperty(session => session.RevokedReason, "logout")
                    .SetProperty(session => session.UpdatedAt, now)
                    .SetProperty(session => session.Version, session => session.Version + 1));
            return updated > 0 || await _context.UserSessions.AsNoTracking().AnyAsync(session =>
                session.Id == sessionId && session.UserId == userId);
        }

        for (var attempt = 0; attempt < 3; attempt++)
        {
            var session = await _context.UserSessions.FirstOrDefaultAsync(item =>
                item.Id == sessionId && item.UserId == userId);
            if (session == null) return false;
            if (session.RevokedAt != null) return true;

            session.RevokedAt = now;
            session.RevokedReason = "logout";
            session.Version++;
            try
            {
                await _context.SaveChangesAsync();
                return true;
            }
            catch (DbUpdateConcurrencyException) when (attempt < 2)
            {
                DetachTrackedSessions();
            }
        }

        throw new InvalidOperationException("会话状态持续冲突，请重试");
    }

    public Task<bool> IsSessionActiveAsync(Guid userId, Guid sessionId) =>
        _context.UserSessions.AsNoTracking().AnyAsync(session =>
            session.Id == sessionId &&
            session.UserId == userId &&
            session.RevokedAt == null &&
            session.ExpiresAt > DateTime.UtcNow);

    public Task<User?> GetUserByIdAsync(Guid userId) =>
        _context.Users.FindAsync(userId).AsTask();

    private async Task<AuthResponse> CreateSessionAsync(
        User user,
        string tokenTransport,
        string? deviceName,
        string? userAgent)
    {
        var clientType = NormalizeTransport(tokenTransport);
        var now = DateTime.UtcNow;
        var session = new UserSession
        {
            User = user,
            UserId = user.Id,
            RefreshTokenHash = [],
            LastUsedAt = now,
            ExpiresAt = now.AddDays(_refreshTokenExpirationDays),
            DeviceName = NormalizeOptional(deviceName, 64),
            ClientType = clientType,
            UserAgent = NormalizeOptional(userAgent, 256)
        };
        var issued = _refreshTokenProtector.Issue(session.Id);
        session.RefreshTokenHash = issued.Hash;
        _context.UserSessions.Add(session);
        await _context.SaveChangesAsync();
        return CreateAuthResponse(user, session, issued.Token);
    }

    private AuthResponse CreateAuthResponse(User user, UserSession session, string refreshToken)
    {
        var accessToken = _jwtService.GenerateAccessToken(user, session.Id);
        var userDto = new UserDto(
            user.Id,
            user.Username,
            user.Email,
            user.Role.ToString(),
            user.AvatarUrl,
            user.CreatedAt);

        return new AuthResponse(
            accessToken,
            refreshToken,
            session.Id,
            session.ExpiresAt,
            userDto);
    }

    private static string NormalizeTransport(string? transport)
    {
        var normalized = transport?.Trim().ToLowerInvariant() ?? "body";
        return normalized is "body" or "cookie"
            ? normalized
            : throw new ArgumentException("tokenTransport 必须是 body 或 cookie");
    }

    private static string? NormalizeOptional(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var normalized = value.Trim();
        if (normalized.Length > maxLength)
            throw new ArgumentException($"值不能超过 {maxLength} 个字符");
        return normalized;
    }

    private void DetachTrackedSessions()
    {
        foreach (var entry in _context.ChangeTracker.Entries<UserSession>())
            entry.State = EntityState.Detached;
    }
}
