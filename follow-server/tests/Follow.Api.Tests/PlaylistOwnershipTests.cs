using Follow.Core.Entities;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public class PlaylistOwnershipTests
{
    [Fact]
    public async Task PublicPlaylist_IsReadableButOnlyOwnerCanEdit()
    {
        await using var context = CreateContext();
        var owner = CreateUser("owner");
        var viewer = CreateUser("viewer");
        var playlist = new Playlist
        {
            Name = "Family mix",
            IsPublic = true,
            User = owner,
            UserId = owner.Id
        };
        context.AddRange(owner, viewer, playlist);
        await context.SaveChangesAsync();
        var service = new PlaylistService(context);

        var detail = await service.GetPlaylistByIdAsync(playlist.Id, viewer.Id);

        Assert.NotNull(detail);
        Assert.Equal(owner.Id, detail.OwnerId);
        Assert.Equal(owner.Username, detail.OwnerName);
        Assert.False(detail.IsOwnedByCurrentUser);
        Assert.False(detail.CanEdit);
        Assert.Null(await service.UpdatePlaylistAsync(
            playlist.Id,
            viewer.Id,
            new UpdatePlaylistRequest("Hijacked", null, true)));
        Assert.Equal("Family mix", (await context.Playlists.SingleAsync()).Name);
    }

    [Fact]
    public async Task OwnerFlags_AreReturnedForListCreateAndDetail()
    {
        await using var context = CreateContext();
        var owner = CreateUser("owner");
        context.Users.Add(owner);
        await context.SaveChangesAsync();
        var service = new PlaylistService(context);

        var created = await service.CreatePlaylistAsync(
            owner.Id,
            new CreatePlaylistRequest("Mine", null, false));
        var listed = Assert.Single(await service.GetUserPlaylistsAsync(owner.Id));
        var detail = await service.GetPlaylistByIdAsync(created.Id, owner.Id);

        Assert.Equal(owner.Id, created.OwnerId);
        Assert.True(created.IsOwnedByCurrentUser);
        Assert.True(created.CanEdit);
        Assert.True(listed.IsOwnedByCurrentUser);
        Assert.True(listed.CanEdit);
        Assert.NotNull(detail);
        Assert.True(detail.IsOwnedByCurrentUser);
        Assert.True(detail.CanEdit);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task NonOwner_CannotMutatePrivateOrPublicPlaylist(bool isPublic)
    {
        await using var context = CreateContext();
        var owner = CreateUser("owner");
        var viewer = CreateUser("viewer");
        var track = new Track { Title = "Song", FilePath = "tracks/song.mp3" };
        var playlist = new Playlist
        {
            Name = "Owner only",
            IsPublic = isPublic,
            User = owner,
            UserId = owner.Id
        };
        context.AddRange(owner, viewer, track, playlist);
        await context.SaveChangesAsync();
        var service = new PlaylistService(context);

        Assert.False(await service.AddTrackToPlaylistAsync(playlist.Id, track.Id, viewer.Id));
        Assert.False(await service.DeletePlaylistAsync(playlist.Id, viewer.Id));
        Assert.Empty(await context.PlaylistTracks.ToListAsync());
        Assert.NotNull(await context.Playlists.FindAsync(playlist.Id));
    }

    [Fact]
    public async Task Reorder_RequiresCompleteUniquePermutation()
    {
        await using var context = CreateContext();
        var owner = CreateUser("owner");
        var first = new Track { Title = "First", FilePath = "tracks/first.mp3" };
        var second = new Track { Title = "Second", FilePath = "tracks/second.mp3" };
        var playlist = new Playlist
        {
            Name = "Mine",
            User = owner,
            UserId = owner.Id,
            PlaylistTracks =
            [
                new PlaylistTrack { Track = first, TrackId = first.Id, Position = 0 },
                new PlaylistTrack { Track = second, TrackId = second.Id, Position = 1 }
            ]
        };
        context.AddRange(owner, first, second, playlist);
        await context.SaveChangesAsync();
        var service = new PlaylistService(context);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            service.ReorderTracksAsync(playlist.Id, owner.Id, [first.Id]));
        await Assert.ThrowsAsync<ArgumentException>(() =>
            service.ReorderTracksAsync(playlist.Id, owner.Id, [first.Id, first.Id]));
        await Assert.ThrowsAsync<ArgumentException>(() =>
            service.ReorderTracksAsync(playlist.Id, owner.Id, [first.Id, Guid.NewGuid()]));

        Assert.True(await service.ReorderTracksAsync(
            playlist.Id,
            owner.Id,
            [second.Id, first.Id]));
        Assert.Equal(
            [second.Id, first.Id],
            await context.PlaylistTracks
                .OrderBy(item => item.Position)
                .Select(item => item.TrackId)
                .ToListAsync());
    }

    private static FollowDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FollowDbContext(options);
    }

    private static User CreateUser(string name) => new()
    {
        Username = name,
        Email = $"{name}@example.com",
        PasswordHash = "hash"
    };
}
