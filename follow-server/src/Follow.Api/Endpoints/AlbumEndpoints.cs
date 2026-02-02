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

        group.MapPost("/{id:guid}/cover", UploadCover)
            .WithName("UploadAlbumCover")
            .WithDescription("Upload cover image for an album (Admin only)")
            .RequireAuthorization(Policies.AdminOnly)
            .DisableAntiforgery();
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

    private static async Task<IResult> UploadCover(
        Guid id,
        IFormFile file,
        IAlbumService albumService)
    {
        if (file.Length == 0)
            return Results.BadRequest(new { error = "No file uploaded" });

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp", ".gif" };
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        
        if (!allowedExtensions.Contains(extension))
            return Results.BadRequest(new { error = "Unsupported image format. Use JPG, PNG, WebP or GIF." });

        try
        {
            await using var stream = file.OpenReadStream();
            var coverUrl = await albumService.UploadAlbumCoverAsync(id, stream, file.FileName, file.ContentType);
            return Results.Ok(new { coverUrl });
        }
        catch (ArgumentException ex)
        {
            return Results.NotFound(new { error = ex.Message });
        }
    }
}
