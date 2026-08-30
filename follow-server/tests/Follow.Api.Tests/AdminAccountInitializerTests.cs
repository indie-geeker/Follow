using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Options;

namespace Follow.Api.Tests;

public class AdminAccountInitializerTests
{
    [Fact]
    public async Task InitializeAsync_CreatesConfiguredAdministrator()
    {
        await using var context = CreateContext();
        var initializer = CreateInitializer(context);

        await initializer.InitializeAsync();

        var admin = await context.Users.SingleAsync();
        Assert.Equal("follow.admin", admin.Username);
        Assert.Equal("admin@follow.local", admin.Email);
        Assert.Equal(UserRole.Admin, admin.Role);
        Assert.Equal("hashed:BootstrapStrong!2026", admin.PasswordHash);
    }

    [Fact]
    public async Task InitializeAsync_IsIdempotentAndRestoresConfiguredCredentials()
    {
        await using var context = CreateContext();
        context.Users.Add(new User
        {
            Username = "follow.admin",
            Email = "admin@follow.local",
            PasswordHash = "old-hash",
            Role = UserRole.Member
        });
        await context.SaveChangesAsync();
        var initializer = CreateInitializer(context);

        await initializer.InitializeAsync();
        await initializer.InitializeAsync();

        var admin = await context.Users.SingleAsync();
        Assert.Equal(UserRole.Admin, admin.Role);
        Assert.Equal("hashed:BootstrapStrong!2026", admin.PasswordHash);
    }

    [Fact]
    public async Task InitializeAsync_RejectsIncompleteConfiguration()
    {
        await using var context = CreateContext();
        var initializer = new AdminAccountInitializer(
            context,
            new TestPasswordHasher(),
            Options.Create(new AdminAccountOptions()));

        await Assert.ThrowsAsync<InvalidOperationException>(() => initializer.InitializeAsync());
    }

    [Fact]
    public async Task InitializeAsync_UnchangedConfigurationDoesNotRehashOrRevokeSessions()
    {
        await using var context = CreateContext();
        var hasher = new CountingPasswordHasher();
        var admin = new User
        {
            Username = "follow.admin",
            Email = "admin@follow.local",
            PasswordHash = "hashed:BootstrapStrong!2026",
            Role = UserRole.Admin,
            UpdatedAt = DateTime.UtcNow.AddDays(-1)
        };
        admin.Sessions.Add(new UserSession
        {
            User = admin,
            UserId = admin.Id,
            RefreshTokenHash = Enumerable.Repeat((byte)1, 32).ToArray(),
            ClientType = "cookie",
            ExpiresAt = DateTime.UtcNow.AddDays(7),
            Version = 4
        });
        context.Users.Add(admin);
        await context.SaveChangesAsync();
        var updatedAt = admin.UpdatedAt;
        var initializer = CreateInitializer(context, hasher);

        await initializer.InitializeAsync();

        Assert.Equal(0, hasher.HashCallCount);
        Assert.Equal(1, hasher.VerifyCallCount);
        Assert.Equal(updatedAt, admin.UpdatedAt);
        var session = await context.UserSessions.SingleAsync();
        Assert.Null(session.RevokedAt);
        Assert.Null(session.RevokedReason);
        Assert.Equal(4, session.Version);
    }

    [Fact]
    public async Task InitializeAsync_ChangedCredentialsRevokeActiveSessionsWithSameSave()
    {
        var saveShape = new SaveShapeInterceptor();
        await using var context = CreateContext(saveShape);
        var hasher = new CountingPasswordHasher();
        var admin = new User
        {
            Username = "old.admin",
            Email = "admin@follow.local",
            PasswordHash = "hashed:OldStrong!2026",
            Role = UserRole.Member
        };
        admin.Sessions.Add(new UserSession
        {
            User = admin,
            UserId = admin.Id,
            RefreshTokenHash = Enumerable.Repeat((byte)1, 32).ToArray(),
            ClientType = "cookie",
            ExpiresAt = DateTime.UtcNow.AddDays(7),
            Version = 2
        });
        admin.Sessions.Add(new UserSession
        {
            User = admin,
            UserId = admin.Id,
            RefreshTokenHash = Enumerable.Repeat((byte)2, 32).ToArray(),
            ClientType = "body",
            ExpiresAt = DateTime.UtcNow.AddDays(7),
            RevokedAt = DateTime.UtcNow.AddHours(-1),
            RevokedReason = "logout",
            Version = 3
        });
        context.Users.Add(admin);
        await context.SaveChangesAsync();
        saveShape.Reset();
        var initializer = CreateInitializer(context, hasher);

        await initializer.InitializeAsync();

        Assert.Equal("follow.admin", admin.Username);
        Assert.Equal(UserRole.Admin, admin.Role);
        Assert.Equal("hashed:BootstrapStrong!2026", admin.PasswordHash);
        Assert.Equal(1, hasher.HashCallCount);
        Assert.Equal(1, hasher.VerifyCallCount);
        var sessions = await context.UserSessions.OrderBy(item => item.Version).ToListAsync();
        var activeBeforeRotation = Assert.Single(sessions, item =>
            item.RevokedReason == "admin-account-rotated");
        Assert.NotNull(activeBeforeRotation.RevokedAt);
        Assert.Equal(3, activeBeforeRotation.Version);
        var alreadyRevoked = Assert.Single(sessions, item => item.RevokedReason == "logout");
        Assert.Equal(3, alreadyRevoked.Version);
        Assert.Equal(1, saveShape.SaveCallCount);
        Assert.True(saveShape.SawModifiedUserAndSessionTogether);
    }

    private static AdminAccountInitializer CreateInitializer(
        FollowDbContext context,
        IPasswordHasher? passwordHasher = null) => new(
        context,
        passwordHasher ?? new TestPasswordHasher(),
        Options.Create(new AdminAccountOptions
        {
            Username = "  Follow.Admin ",
            Email = " ADMIN@Follow.Local ",
            Password = "BootstrapStrong!2026"
        }));

    private static FollowDbContext CreateContext(params IInterceptor[] interceptors)
    {
        var builder = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString());
        if (interceptors.Length > 0) builder.AddInterceptors(interceptors);
        var options = builder.Options;

        return new FollowDbContext(options);
    }

    private sealed class TestPasswordHasher : IPasswordHasher
    {
        public string HashPassword(string password) => $"hashed:{password}";

        public bool VerifyPassword(string password, string hashedPassword) =>
            hashedPassword == $"hashed:{password}";
    }

    private sealed class CountingPasswordHasher : IPasswordHasher
    {
        public int HashCallCount { get; private set; }
        public int VerifyCallCount { get; private set; }

        public string HashPassword(string password)
        {
            HashCallCount++;
            return $"hashed:{password}";
        }

        public bool VerifyPassword(string password, string hashedPassword)
        {
            VerifyCallCount++;
            return hashedPassword == $"hashed:{password}";
        }
    }

    private sealed class SaveShapeInterceptor : SaveChangesInterceptor
    {
        public int SaveCallCount { get; private set; }
        public bool SawModifiedUserAndSessionTogether { get; private set; }

        public void Reset()
        {
            SaveCallCount = 0;
            SawModifiedUserAndSessionTogether = false;
        }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            SaveCallCount++;
            var entries = eventData.Context!.ChangeTracker.Entries().ToList();
            SawModifiedUserAndSessionTogether =
                entries.Any(entry => entry.Entity is User && entry.State == EntityState.Modified) &&
                entries.Any(entry => entry.Entity is UserSession && entry.State == EntityState.Modified);
            return ValueTask.FromResult(result);
        }
    }
}
