using System.Security.Claims;
using Follow.Core.Interfaces;
using Follow.Shared.DTOs;

namespace Follow.Api.Endpoints;

public static class PlaylistEndpoints
{
    public static void MapPlaylistEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/playlists").WithTags("Playlists");

        group.MapGet("/", GetPlaylists)
            .WithName("GetPlaylists")
            .WithDescription("Get all playlists for current user")
            .RequireAuthorization();

        group.MapGet("/{id:guid}", GetPlaylistById)
            .WithName("GetPlaylistById")
            .WithDescription("Get a playlist with tracks")
            .RequireAuthorization();

        group.MapPost("/", CreatePlaylist)
            .WithName("CreatePlaylist")
            .WithDescription("Create a new playlist")
            .RequireAuthorization();

        group.MapPut("/{id:guid}", UpdatePlaylist)
            .WithName("UpdatePlaylist")
            .WithDescription("Update a playlist")
            .RequireAuthorization();

        group.MapDelete("/{id:guid}", DeletePlaylist)
            .WithName("DeletePlaylist")
            .WithDescription("Delete a playlist")
            .RequireAuthorization();

        group.MapPost("/{id:guid}/tracks", AddTrackToPlaylist)
            .WithName("AddTrackToPlaylist")
            .WithDescription("Add a track to a playlist")
            .RequireAuthorization();

        group.MapDelete("/{id:guid}/tracks/{trackId:guid}", RemoveTrackFromPlaylist)
            .WithName("RemoveTrackFromPlaylist")
            .WithDescription("Remove a track from a playlist")
            .RequireAuthorization();

        group.MapPut("/{id:guid}/tracks/reorder", ReorderTracks)
            .WithName("ReorderTracks")
            .WithDescription("Reorder tracks in a playlist")
            .RequireAuthorization();
    }

    private static Guid? GetUserId(ClaimsPrincipal user)
    {
        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    private static async Task<IResult> GetPlaylists(
        ClaimsPrincipal user,
        IPlaylistService playlistService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var playlists = await playlistService.GetUserPlaylistsAsync(userId.Value);
        return Results.Ok(playlists);
    }

    private static async Task<IResult> GetPlaylistById(
        Guid id,
        ClaimsPrincipal user,
        IPlaylistService playlistService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var playlist = await playlistService.GetPlaylistByIdAsync(id, userId.Value);
        return playlist == null ? Results.NotFound() : Results.Ok(playlist);
    }

    private static async Task<IResult> CreatePlaylist(
        CreatePlaylistRequest request,
        ClaimsPrincipal user,
        IPlaylistService playlistService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var playlist = await playlistService.CreatePlaylistAsync(userId.Value, request);
        return Results.Created($"/api/playlists/{playlist.Id}", playlist);
    }

    private static async Task<IResult> UpdatePlaylist(
        Guid id,
        UpdatePlaylistRequest request,
        ClaimsPrincipal user,
        IPlaylistService playlistService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var playlist = await playlistService.UpdatePlaylistAsync(id, userId.Value, request);
        return playlist == null ? Results.NotFound() : Results.Ok(playlist);
    }

    private static async Task<IResult> DeletePlaylist(
        Guid id,
        ClaimsPrincipal user,
        IPlaylistService playlistService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var success = await playlistService.DeletePlaylistAsync(id, userId.Value);
        return success ? Results.NoContent() : Results.NotFound();
    }

    private static async Task<IResult> AddTrackToPlaylist(
        Guid id,
        AddTrackToPlaylistRequest request,
        ClaimsPrincipal user,
        IPlaylistService playlistService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var success = await playlistService.AddTrackToPlaylistAsync(id, request.TrackId, userId.Value);
        return success ? Results.Ok() : Results.NotFound();
    }

    private static async Task<IResult> RemoveTrackFromPlaylist(
        Guid id,
        Guid trackId,
        ClaimsPrincipal user,
        IPlaylistService playlistService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var success = await playlistService.RemoveTrackFromPlaylistAsync(id, trackId, userId.Value);
        return success ? Results.NoContent() : Results.NotFound();
    }

    private static async Task<IResult> ReorderTracks(
        Guid id,
        ReorderTracksRequest request,
        ClaimsPrincipal user,
        IPlaylistService playlistService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var success = await playlistService.ReorderTracksAsync(id, userId.Value, request.TrackIds);
        return success ? Results.Ok() : Results.NotFound();
    }
}

public record ReorderTracksRequest(List<Guid> TrackIds);
