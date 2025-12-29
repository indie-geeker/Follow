using System.Security.Claims;
using Follow.Core.Interfaces;

namespace Follow.Api.Endpoints;

public static class RssEndpoints
{
    public static void MapRssEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/rss").WithTags("RSS Subscriptions").RequireAuthorization();

        group.MapGet("/subscriptions", GetSubscriptions)
            .WithName("GetRssSubscriptions")
            .WithDescription("Get all RSS subscriptions");

        group.MapGet("/subscriptions/{id:guid}", GetSubscriptionById)
            .WithName("GetRssSubscriptionById");

        group.MapPost("/subscriptions", AddSubscription)
            .WithName("AddRssSubscription")
            .WithDescription("Add a new RSS subscription");

        group.MapDelete("/subscriptions/{id:guid}", RemoveSubscription)
            .WithName("RemoveRssSubscription");

        group.MapPost("/subscriptions/{id:guid}/refresh", RefreshSubscription)
            .WithName("RefreshRssSubscription")
            .WithDescription("Refresh feed to get new episodes");

        group.MapGet("/subscriptions/{id:guid}/episodes", GetEpisodes)
            .WithName("GetRssEpisodes");

        group.MapPost("/episodes/{id:guid}/played", MarkEpisodePlayed)
            .WithName("MarkEpisodePlayed");
    }

    private static Guid? GetUserId(ClaimsPrincipal user)
    {
        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    private static async Task<IResult> GetSubscriptions(
        ClaimsPrincipal user,
        IRssService rssService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var subscriptions = await rssService.GetSubscriptionsAsync(userId.Value);
        return Results.Ok(subscriptions);
    }

    private static async Task<IResult> GetSubscriptionById(
        Guid id,
        ClaimsPrincipal user,
        IRssService rssService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var subscription = await rssService.GetSubscriptionByIdAsync(id, userId.Value);
        return subscription == null ? Results.NotFound() : Results.Ok(subscription);
    }

    private static async Task<IResult> AddSubscription(
        AddRssSubscriptionRequest request,
        ClaimsPrincipal user,
        IRssService rssService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var subscription = await rssService.AddSubscriptionAsync(userId.Value, request);
        return Results.Created($"/api/rss/subscriptions/{subscription.Id}", subscription);
    }

    private static async Task<IResult> RemoveSubscription(
        Guid id,
        ClaimsPrincipal user,
        IRssService rssService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var success = await rssService.RemoveSubscriptionAsync(id, userId.Value);
        return success ? Results.NoContent() : Results.NotFound();
    }

    private static async Task<IResult> RefreshSubscription(
        Guid id,
        ClaimsPrincipal user,
        IRssService rssService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var subscription = await rssService.RefreshSubscriptionAsync(id, userId.Value);
        return subscription == null ? Results.NotFound() : Results.Ok(subscription);
    }

    private static async Task<IResult> GetEpisodes(
        Guid id,
        ClaimsPrincipal user,
        IRssService rssService,
        int page = 1,
        int pageSize = 50)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var episodes = await rssService.GetEpisodesAsync(id, userId.Value, page, pageSize);
        return Results.Ok(episodes);
    }

    private static async Task<IResult> MarkEpisodePlayed(
        Guid id,
        ClaimsPrincipal user,
        IRssService rssService)
    {
        var userId = GetUserId(user);
        if (userId == null) return Results.Unauthorized();

        var success = await rssService.MarkEpisodePlayedAsync(id, userId.Value);
        return success ? Results.Ok() : Results.NotFound();
    }
}
