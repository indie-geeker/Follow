using Follow.Core.Entities;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public class PaginationContractTests
{
    [Theory]
    [InlineData(0, 20)]
    [InlineData(-1, 20)]
    [InlineData(1, 0)]
    [InlineData(1, 101)]
    public void PaginationPolicy_RejectsInvalidBounds(int page, int pageSize)
    {
        Assert.Throws<ArgumentException>(() => PaginationPolicy.Validate(page, pageSize));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(101)]
    public void PaginationPolicy_RejectsInvalidLimit(int limit)
    {
        Assert.Throws<ArgumentException>(() => PaginationPolicy.ValidateLimit(limit));
    }

    [Fact]
    public void PaginationPolicy_RejectsOverflowingOffset()
    {
        Assert.Throws<ArgumentException>(() =>
            PaginationPolicy.GetOffset(int.MaxValue, 100));
    }

    [Fact]
    public async Task TrackPage_UsesIdAsStableTieBreakerAndNoTracking()
    {
        await using var context = CreateContext();
        var createdAt = DateTime.UtcNow;
        var first = new Track
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000002"),
            Title = "Second by id",
            FilePath = "tracks/second.mp3",
            CreatedAt = createdAt
        };
        var second = new Track
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000001"),
            Title = "First by id",
            FilePath = "tracks/first.mp3",
            CreatedAt = createdAt
        };
        context.Tracks.AddRange(first, second);
        await context.SaveChangesAsync();
        context.ChangeTracker.Clear();
        var service = ServiceFactory.CreateTrackService(context);

        var result = await service.GetTracksAsync(1, 100);

        Assert.Equal([second.Id, first.Id], result.Tracks.Select(track => track.Id));
        Assert.Empty(context.ChangeTracker.Entries());
    }

    [Fact]
    public async Task PaginatedServices_RejectInvalidBoundsBeforeQuerying()
    {
        await using var context = CreateContext();
        var trackService = ServiceFactory.CreateTrackService(context);
        var tagService = new TagService(context);
        var adminService = new AdminService(context, new StubPasswordHasher());
        var userMusicService = new UserMusicService(context);

        await Assert.ThrowsAsync<ArgumentException>(() => trackService.GetTracksAsync(0, 20));
        await Assert.ThrowsAsync<ArgumentException>(() => tagService.GetTracksByTagAsync(Guid.NewGuid(), 1, 101));
        await Assert.ThrowsAsync<ArgumentException>(() => adminService.GetUsersAsync(-1, 20));
        await Assert.ThrowsAsync<ArgumentException>(() => userMusicService.GetPlayHistoryAsync(Guid.NewGuid(), 0));
    }

    private static FollowDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FollowDbContext(options);
    }

    private sealed class StubPasswordHasher : Follow.Core.Interfaces.IPasswordHasher
    {
        public string HashPassword(string password) => password;
        public bool VerifyPassword(string password, string hashedPassword) => password == hashedPassword;
    }
}
