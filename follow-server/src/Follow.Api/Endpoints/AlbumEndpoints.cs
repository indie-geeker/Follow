using Follow.Core.Interfaces;
using Follow.Shared.Constants;
using Follow.Shared.DTOs;

namespace Follow.Api.Endpoints;

public static class AlbumEndpoints
{
    public static void MapAlbumEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/albums").WithTags("Albums");

        group.MapGet("/", GetAlbums)
            .WithName("GetAlbums")
            .RequireAuthorization();

        group.MapGet("/{id:guid}", GetAlbumById)
            .WithName("GetAlbumById")
            .RequireAuthorization();

        group.MapPost("/", CreateAlbum)
            .WithName("CreateAlbum")
            .RequireAuthorization(Policies.AdminOnly);

        group.MapPut("/{id:guid}", UpdateAlbum)
            .WithName("UpdateAlbum")
            .RequireAuthorization(Policies.AdminOnly);

        group.MapDelete("/{id:guid}", DeleteAlbum)
            .WithName("DeleteAlbum")
            .RequireAuthorization(Policies.AdminOnly);
    }

    private static async Task<IResult> GetAlbums(IAlbumService albumService)
    {
        var albums = await albumService.GetAlbumsAsync();
        return Results.Ok(albums);
    }

    private static async Task<IResult> GetAlbumById(Guid id, IAlbumService albumService)
    {
        var album = await albumService.GetAlbumByIdAsync(id);
        return album == null ? Results.NotFound() : Results.Ok(album);
    }

    private static async Task<IResult> CreateAlbum(CreateAlbumRequest request, IAlbumService albumService)
    {
        var album = await albumService.CreateAlbumAsync(request);
        return Results.Created($"/api/albums/{album.Id}", album);
    }

    private static async Task<IResult> UpdateAlbum(Guid id, UpdateAlbumRequest request, IAlbumService albumService)
    {
        var album = await albumService.UpdateAlbumAsync(id, request);
        return album == null ? Results.NotFound() : Results.Ok(album);
    }

    private static async Task<IResult> DeleteAlbum(Guid id, IAlbumService albumService)
    {
        var success = await albumService.DeleteAlbumAsync(id);
        return success ? Results.NoContent() : Results.NotFound();
    }
}
