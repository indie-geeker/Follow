using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Configuration;

namespace Follow.Api.Tests;

public class AuthSessionServiceTests
{
    [Fact]
    public async Task Register_StoresOnlyRefreshTokenHash()
    {
        await using var context = CreateContext();
        var service = CreateService(context);

        var response = await service.RegisterAsync(new RegisterRequest(
            "member",
            "member@example.com",
            "StrongPassword!2026",
            "body",
            "Family iPhone"));

        var session = await context.UserSessions.SingleAsync();
        Assert.Equal(response.SessionId, session.Id);
        Assert.NotNull(response.RefreshToken);
        Assert.DoesNotContain(response.RefreshToken!, Convert.ToHexString(session.RefreshTokenHash));
        Assert.Equal("Family iPhone", session.DeviceName);
        Assert.Equal("body", session.ClientType);
    }

    [Fact]
    public async Task Login_CreatesIndependentSessionsForTwoDevices()
    {
        await using var context = CreateContext();
        var service = CreateService(context);
        await service.RegisterAsync(new RegisterRequest(
            "member", "member@example.com", "StrongPassword!2026"));

        var phone = await service.LoginAsync(new LoginRequest(
            "member@example.com", "StrongPassword!2026", "body", "Phone"));
        var browser = await service.LoginAsync(new LoginRequest(
            "member@example.com", "StrongPassword!2026", "cookie", "Browser"));

        Assert.NotEqual(phone.SessionId, browser.SessionId);
        Assert.NotEqual(phone.RefreshToken, browser.RefreshToken);
        Assert.Equal(3, await context.UserSessions.CountAsync(session => session.RevokedAt == null));
    }

    [Fact]
    public async Task Refresh_RotatesTokenAndRejectsStaleToken()
    {
        await using var context = CreateContext();
        var service = CreateService(context);
        var registered = await service.RegisterAsync(new RegisterRequest(
            "member", "member@example.com", "StrongPassword!2026"));

        var refreshed = await service.RefreshTokenAsync(
            new RefreshTokenRequest(registered.RefreshToken));

        Assert.Equal(registered.SessionId, refreshed.SessionId);
        Assert.NotEqual(registered.RefreshToken, refreshed.RefreshToken);
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            service.RefreshTokenAsync(new RefreshTokenRequest(registered.RefreshToken)));
        Assert.False(await service.IsSessionActiveAsync(
            registered.User.Id,
            registered.SessionId));
    }

    [Fact]
    public async Task Logout_RevokesOnlyCurrentSession()
    {
        await using var context = CreateContext();
        var service = CreateService(context);
        var first = await service.RegisterAsync(new RegisterRequest(
            "member", "member@example.com", "StrongPassword!2026"));
        var second = await service.LoginAsync(new LoginRequest(
            "member@example.com", "StrongPassword!2026", "body", "Second"));

        Assert.True(await service.LogoutAsync(first.User.Id, first.SessionId));

        Assert.False(await service.IsSessionActiveAsync(first.User.Id, first.SessionId));
        Assert.True(await service.IsSessionActiveAsync(second.User.Id, second.SessionId));
    }

    [Fact]
    public async Task SessionOwner_CannotRevokeAnotherUsersSession()
    {
        await using var context = CreateContext();
        var service = CreateService(context);
        var first = await service.RegisterAsync(new RegisterRequest(
            "first", "first@example.com", "StrongPassword!2026"));
        var second = await service.RegisterAsync(new RegisterRequest(
            "second", "second@example.com", "StrongPassword!2026"));

        Assert.False(await service.RevokeSessionAsync(first.User.Id, second.SessionId));
        Assert.True(await service.IsSessionActiveAsync(second.User.Id, second.SessionId));
    }

    [Fact]
    public async Task ConcurrentRefresh_AllowsExactlyOneRotation()
    {
        var databaseName = Guid.NewGuid().ToString();
        var databaseRoot = new InMemoryDatabaseRoot();
        var seedOptions = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(databaseName, databaseRoot)
            .Options;
        AuthResponse registered;
        await using (var seedContext = new FollowDbContext(seedOptions))
        {
            registered = await CreateService(seedContext).RegisterAsync(new RegisterRequest(
                "member", "member@example.com", "StrongPassword!2026"));
        }

        var interceptor = new CoordinatedSaveInterceptor(2);
        var concurrentOptions = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(databaseName, databaseRoot)
            .AddInterceptors(interceptor)
            .Options;
        await using var firstContext = new FollowDbContext(concurrentOptions);
        await using var secondContext = new FollowDbContext(concurrentOptions);
        var firstService = CreateService(firstContext);
        var secondService = CreateService(secondContext);

        var outcomes = await Task.WhenAll(
            CaptureRefresh(firstService, registered.RefreshToken),
            CaptureRefresh(secondService, registered.RefreshToken));

        Assert.Single(outcomes.OfType<AuthResponse>());
        Assert.Single(outcomes.OfType<InvalidOperationException>());
    }

    [Fact]
    public async Task ConcurrentRefreshAndLogout_AlwaysEndsRevoked()
    {
        var databaseName = Guid.NewGuid().ToString();
        var databaseRoot = new InMemoryDatabaseRoot();
        var seedOptions = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(databaseName, databaseRoot)
            .Options;
        AuthResponse registered;
        await using (var seedContext = new FollowDbContext(seedOptions))
        {
            registered = await CreateService(seedContext).RegisterAsync(new RegisterRequest(
                "member", "member@example.com", "StrongPassword!2026"));
        }

        var interceptor = new CoordinatedSaveInterceptor(2);
        var concurrentOptions = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(databaseName, databaseRoot)
            .AddInterceptors(interceptor)
            .Options;
        await using var refreshContext = new FollowDbContext(concurrentOptions);
        await using var logoutContext = new FollowDbContext(concurrentOptions);
        var refreshService = CreateService(refreshContext);
        var logoutService = CreateService(logoutContext);

        await Task.WhenAll(
            CaptureRefresh(refreshService, registered.RefreshToken),
            logoutService.LogoutAsync(registered.User.Id, registered.SessionId));

        await using var verificationContext = new FollowDbContext(seedOptions);
        Assert.False(await CreateService(verificationContext).IsSessionActiveAsync(
            registered.User.Id,
            registered.SessionId));
    }

    private static FollowDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        return new FollowDbContext(options);
    }

    private static AuthService CreateService(FollowDbContext context)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["JwtSettings:RefreshTokenExpirationDays"] = "7"
            })
            .Build();

        return new AuthService(
            context,
            new TestPasswordHasher(),
            new TestJwtService(),
            new RefreshTokenProtector(),
            configuration);
    }

    private static async Task<object> CaptureRefresh(
        AuthService service,
        string? refreshToken)
    {
        try
        {
            return await service.RefreshTokenAsync(new RefreshTokenRequest(refreshToken));
        }
        catch (Exception exception)
        {
            return exception;
        }
    }

    private sealed class TestPasswordHasher : IPasswordHasher
    {
        public string HashPassword(string password) => $"hashed:{password}";

        public bool VerifyPassword(string password, string hashedPassword) =>
            hashedPassword == $"hashed:{password}";
    }

    private sealed class TestJwtService : IJwtService
    {
        public string GenerateAccessToken(User user, Guid sessionId) =>
            $"access:{user.Email}:{sessionId}";
    }

    private sealed class CoordinatedSaveInterceptor : SaveChangesInterceptor
    {
        private readonly int _participantCount;
        private readonly TaskCompletionSource _allReady = new(
            TaskCreationOptions.RunContinuationsAsynchronously);
        private int _readyCount;

        public CoordinatedSaveInterceptor(int participantCount)
        {
            _participantCount = participantCount;
        }

        public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            if (Interlocked.Increment(ref _readyCount) == _participantCount)
                _allReady.TrySetResult();

            await _allReady.Task.WaitAsync(cancellationToken);
            return result;
        }
    }
}
