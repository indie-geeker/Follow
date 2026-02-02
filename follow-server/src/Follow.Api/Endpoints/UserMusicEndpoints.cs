using System.Security.Claims;
using Follow.Core.Interfaces;

namespace Follow.Api.Endpoints;

public static class UserMusicEndpoints
{
    public static void MapUserMusicEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/user").WithTags("User Music");

        // Favorites
        group.MapGet("/favorites", GetFavorites)
            .WithName("GetFavorites")
            .RequireAuthorization();

        group.MapPost("/favorites/{trackId:guid}", AddToFavorites)
            .WithName("AddToFavorites")
            .RequireAuthorization();

        group.MapDelete("/favorites/{trackId:guid}", RemoveFromFavorites)
            .WithName("RemoveFromFavorites")
            .RequireAuthorization();

        group.MapGet("/favorites/{trackId:guid}/check", CheckFavorite)
            .WithName("CheckFavorite")
            .RequireAuthorization();

        // Play History
        group.MapGet("/history", GetPlayHistory)
            .WithName("GetPlayHistory")
            .RequireAuthorization();

        group.MapPost("/history", RecordPlayHistory)
            .WithName("RecordPlayHistory")
            .RequireAuthorization();

        group.MapDelete("/history/{trackId:guid}", RemoveFromHistory)
            .WithName("RemoveFromHistory")
            .RequireAuthorization();
    }

    private static Guid? GetUserId(ClaimsPrincipal user)
    {
        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    private static async Task<IResult> GetFavorites(
        ClaimsPrincipal user,
        IUserMusicService userMusicService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var favorites = await userMusicService.GetFavoritesAsync(userId.Value);
        return Results.Ok(favorites);
    }

    private static async Task<IResult> AddToFavorites(
        Guid trackId,
        ClaimsPrincipal user,
        IUserMusicService userMusicService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var success = await userMusicService.AddToFavoritesAsync(userId.Value, trackId);
        return success ? Results.Ok() : Results.NotFound();
    }

    private static async Task<IResult> RemoveFromFavorites(
        Guid trackId,
        ClaimsPrincipal user,
        IUserMusicService userMusicService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var success = await userMusicService.RemoveFromFavoritesAsync(userId.Value, trackId);
        return success ? Results.NoContent() : Results.NotFound();
    }

    private static async Task<IResult> CheckFavorite(
        Guid trackId,
        ClaimsPrincipal user,
        IUserMusicService userMusicService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var isFavorite = await userMusicService.IsFavoriteAsync(userId.Value, trackId);
        return Results.Ok(new { isFavorite });
    }

    private static async Task<IResult> GetPlayHistory(
        ClaimsPrincipal user,
        IUserMusicService userMusicService,
        int limit = 50)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var history = await userMusicService.GetPlayHistoryAsync(userId.Value, limit);
        return Results.Ok(history);
    }

    private static async Task<IResult> RecordPlayHistory(
        RecordPlayRequest request,
        ClaimsPrincipal user,
        IUserMusicService userMusicService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        await userMusicService.AddToPlayHistoryAsync(userId.Value, request.TrackId, request.PlayDurationSeconds);
        return Results.Ok();
    }

    private static async Task<IResult> RemoveFromHistory(
        Guid trackId,
        ClaimsPrincipal user,
        IUserMusicService userMusicService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var success = await userMusicService.RemoveFromPlayHistoryAsync(userId.Value, trackId);
        return success ? Results.NoContent() : Results.NotFound();
    }
}

public record RecordPlayRequest(Guid TrackId, int PlayDurationSeconds);
