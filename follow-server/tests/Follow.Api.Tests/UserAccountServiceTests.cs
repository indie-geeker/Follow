using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Follow.Api.Tests;

public class UserAccountServiceTests
{
    [Fact]
    public async Task PublicRegistration_AlwaysCreatesNormalizedMember()
    {
        await using var context = CreateContext();
        var service = CreateAuthService(context);

        var response = await service.RegisterAsync(new RegisterRequest(
            "  Ｍember.User  ",
            "  MEMBER@Example.com ",
            "StrongPassword!2026"));

        Assert.Equal("member.user", response.User.Username);
        Assert.Equal("member@example.com", response.User.Email);
        Assert.Equal(nameof(UserRole.Member), response.User.Role);
        Assert.Equal(nameof(UserRole.Member), (await context.Users.SingleAsync()).Role.ToString());
    }

    [Fact]
    public async Task PublicRegistration_RejectsWeakPassword()
    {
        await using var context = CreateContext();
        var service = CreateAuthService(context);

        await Assert.ThrowsAsync<ArgumentException>(() => service.RegisterAsync(
            new RegisterRequest("member", "member@example.com", "password")));
    }

    [Fact]
    public async Task AdminCreateUser_CreatesRequestedRoleWithNormalizedCredentials()
    {
        await using var context = CreateContext();
        var service = new AdminService(context, new TestPasswordHasher());

        var user = await service.CreateUserAsync(new CreateUserRequest(
            "  Invited.User ",
            " INVITED@Example.com ",
            "StrongPassword!2026",
            "Admin"));

        Assert.Equal("invited.user", user.Username);
        Assert.Equal("invited@example.com", user.Email);
        Assert.Equal(nameof(UserRole.Admin), user.Role);
    }

    [Fact]
    public async Task AdminCreateUser_RejectsCanonicalDuplicate()
    {
        await using var context = CreateContext();
        var service = new AdminService(context, new TestPasswordHasher());

        await service.CreateUserAsync(new CreateUserRequest(
            "member.user",
            "member@example.com",
            "StrongPassword!2026",
            "Member"));

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.CreateUserAsync(
            new CreateUserRequest(
                " MEMBER.USER ",
                "another@example.com",
                "AnotherStrong!2026",
                "Member")));
    }

    [Fact]
    public async Task AdminCreateUser_RejectsNumericRoleValues()
    {
        await using var context = CreateContext();
        var service = new AdminService(context, new TestPasswordHasher());

        await Assert.ThrowsAsync<ArgumentException>(() => service.CreateUserAsync(
            new CreateUserRequest(
                "member",
                "member@example.com",
                "StrongPassword!2026",
                "0")));
    }

    [Fact]
    public async Task UpdateRole_CannotDemoteLastAdministrator()
    {
        await using var context = CreateContext();
        var admin = new User
        {
            Username = "admin",
            Email = "admin@example.com",
            PasswordHash = "hash",
            Role = UserRole.Admin
        };
        context.Users.Add(admin);
        await context.SaveChangesAsync();
        var service = new AdminService(context, new TestPasswordHasher());

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.UpdateUserRoleAsync(admin.Id, UserRole.Member));

        Assert.Equal(UserRole.Admin, (await context.Users.SingleAsync()).Role);
    }

    [Fact]
    public async Task UpdateRole_RevokesExistingSessionsInSameSave()
    {
        await using var context = CreateContext();
        var user = new User
        {
            Username = "member",
            Email = "member@example.com",
            PasswordHash = "hash",
            Role = UserRole.Member
        };
        user.Sessions.Add(new UserSession
        {
            User = user,
            UserId = user.Id,
            RefreshTokenHash = new byte[32],
            ClientType = "body",
            ExpiresAt = DateTime.UtcNow.AddDays(7)
        });
        context.Users.Add(user);
        await context.SaveChangesAsync();
        var service = new AdminService(context, new TestPasswordHasher());

        await service.UpdateUserRoleAsync(user.Id, UserRole.Admin);

        var session = await context.UserSessions.SingleAsync();
        Assert.NotNull(session.RevokedAt);
        Assert.Equal("role-changed", session.RevokedReason);
        Assert.Equal(1, session.Version);
    }

    [Theory]
    [InlineData("0")]
    [InlineData("99")]
    public void RoleParser_RejectsNumericValues(string value)
    {
        Assert.False(Follow.Api.Endpoints.AdminEndpoints.TryParseRole(value, out _));
    }

    private static FollowDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        return new FollowDbContext(options);
    }

    private static AuthService CreateAuthService(FollowDbContext context)
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
}
