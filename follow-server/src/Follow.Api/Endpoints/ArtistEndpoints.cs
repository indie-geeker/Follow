using Follow.Core.Interfaces;
using Follow.Shared.Constants;
using Follow.Shared.DTOs;

namespace Follow.Api.Endpoints;

public static class ArtistEndpoints
{
    public static void MapArtistEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/artists").WithTags("Artists");

        group.MapGet("/", GetArtists)
            .WithName("GetArtists")
            .RequireAuthorization();

        group.MapGet("/{id:guid}", GetArtistById)
            .WithName("GetArtistById")
            .RequireAuthorization();

        group.MapPost("/", CreateArtist)
            .WithName("CreateArtist")
            .RequireAuthorization(Policies.AdminOnly);

        group.MapPut("/{id:guid}", UpdateArtist)
            .WithName("UpdateArtist")
            .RequireAuthorization(Policies.AdminOnly);

        group.MapDelete("/{id:guid}", DeleteArtist)
            .WithName("DeleteArtist")
            .RequireAuthorization(Policies.AdminOnly);
    }

    private static async Task<IResult> GetArtists(IArtistService artistService)
    {
        var artists = await artistService.GetArtistsAsync();
        return Results.Ok(artists);
    }

    private static async Task<IResult> GetArtistById(Guid id, IArtistService artistService)
    {
        var artist = await artistService.GetArtistByIdAsync(id);
        return artist == null ? Results.NotFound() : Results.Ok(artist);
    }

    private static async Task<IResult> CreateArtist(CreateArtistRequest request, IArtistService artistService)
    {
        var artist = await artistService.CreateArtistAsync(request);
        return Results.Created($"/api/artists/{artist.Id}", artist);
    }

    private static async Task<IResult> UpdateArtist(Guid id, UpdateArtistRequest request, IArtistService artistService)
    {
        var artist = await artistService.UpdateArtistAsync(id, request);
        return artist == null ? Results.NotFound() : Results.Ok(artist);
    }

    private static async Task<IResult> DeleteArtist(Guid id, IArtistService artistService)
    {
        var success = await artistService.DeleteArtistAsync(id);
        return success ? Results.NoContent() : Results.NotFound();
    }
}
