using System.Security.Claims;
using Follow.Core.Interfaces;
using Follow.Shared.Constants;

namespace Follow.Api.Endpoints;

public static class TrackEndpoints
{
    public static void MapTrackEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/tracks").WithTags("Tracks");

        // Public endpoints (authenticated users)
        group.MapGet("/", GetTracks)
            .WithName("GetTracks")
            .WithDescription("Get all tracks with pagination")
            .RequireAuthorization();

        group.MapGet("/{id:guid}", GetTrackById)
            .WithName("GetTrackById")
            .WithDescription("Get a track by ID")
            .RequireAuthorization();

        group.MapGet("/{id:guid}/stream", StreamTrack)
            .WithName("StreamTrack")
            .WithDescription("Stream audio for playback")
            .RequireAuthorization();

        // Admin endpoints
        group.MapPost("/upload", UploadTrack)
            .WithName("UploadTrack")
            .WithDescription("Upload a new track (Admin only)")
            .RequireAuthorization(Policies.AdminOnly)
            .DisableAntiforgery();

        group.MapPost("/{id:guid}/cover", UploadCover)
            .WithName("UploadTrackCover")
            .WithDescription("Upload cover image for a track (Admin only)")
            .RequireAuthorization(Policies.AdminOnly)
            .DisableAntiforgery();

        group.MapPost("/{id:guid}/lyrics", UploadLyrics)
            .WithName("UploadTrackLyrics")
            .WithDescription("Upload lyrics file for a track (Admin only)")
            .RequireAuthorization(Policies.AdminOnly)
            .DisableAntiforgery();

        group.MapGet("/{id:guid}/lyrics", GetLyrics)
            .WithName("GetTrackLyrics")
            .WithDescription("Get lyrics for a track")
            .RequireAuthorization();

        group.MapPut("/{id:guid}", UpdateTrack)
            .WithName("UpdateTrack")
            .WithDescription("Update track metadata (Admin only)")
            .RequireAuthorization(Policies.AdminOnly);

        group.MapDelete("/{id:guid}", DeleteTrack)
            .WithName("DeleteTrack")
            .WithDescription("Delete a track (Admin only)")
            .RequireAuthorization(Policies.AdminOnly);
    }

    private static async Task<IResult> GetTracks(
        ITrackService trackService,
        int page = 1,
        int pageSize = 20,
        string? search = null)
    {
        var (tracks, totalCount) = await trackService.GetTracksAsync(page, pageSize, search);
        return Results.Ok(new
        {
            tracks,
            totalCount,
            page,
            pageSize,
            totalPages = (int)Math.Ceiling((double)totalCount / pageSize)
        });
    }

    private static async Task<IResult> GetTrackById(Guid id, ITrackService trackService)
    {
        var track = await trackService.GetTrackByIdAsync(id);
        return track == null ? Results.NotFound() : Results.Ok(track);
    }

    private static async Task<IResult> StreamTrack(Guid id, ITrackService trackService, HttpContext context)
    {
        var (stream, contentType, length) = await trackService.GetTrackStreamAsync(id);
        
        if (stream == null)
            return Results.NotFound();

        context.Response.Headers["Accept-Ranges"] = "bytes";
        context.Response.Headers["Content-Length"] = length?.ToString();
        
        return Results.Stream(stream, contentType ?? "audio/mpeg", enableRangeProcessing: true);
    }

    private static async Task<IResult> UploadTrack(
        IFormFile file,
        ITrackService trackService)
    {
        if (file.Length == 0)
            return Results.BadRequest(new { error = "No file uploaded" });

        var allowedExtensions = new[] { ".mp3", ".flac", ".wav", ".aac", ".ogg", ".m4a" };
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        
        if (!allowedExtensions.Contains(extension))
            return Results.BadRequest(new { error = "Unsupported audio format" });

        await using var stream = file.OpenReadStream();
        var track = await trackService.UploadTrackAsync(stream, file.FileName, file.ContentType);
        
        return Results.Created($"/api/tracks/{track.Id}", track);
    }

    private static async Task<IResult> UpdateTrack(
        Guid id,
        UpdateTrackRequest request,
        ITrackService trackService)
    {
        var track = await trackService.UpdateTrackAsync(id, request);
        return track == null ? Results.NotFound() : Results.Ok(track);
    }

    private static async Task<IResult> DeleteTrack(Guid id, ITrackService trackService)
    {
        var success = await trackService.DeleteTrackAsync(id);
        return success ? Results.NoContent() : Results.NotFound();
    }

    private static async Task<IResult> UploadCover(
        Guid id,
        IFormFile file,
        ITrackService trackService)
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
            var coverUrl = await trackService.UploadTrackCoverAsync(id, stream, file.FileName, file.ContentType);
            return Results.Ok(new { coverUrl });
        }
        catch (ArgumentException ex)
        {
            return Results.NotFound(new { error = ex.Message });
        }
    }

    private static async Task<IResult> UploadLyrics(
        Guid id,
        IFormFile file,
        ITrackService trackService)
    {
        if (file.Length == 0)
            return Results.BadRequest(new { error = "No file uploaded" });

        var allowedExtensions = new[] { ".lrc", ".txt" };
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        
        if (!allowedExtensions.Contains(extension))
            return Results.BadRequest(new { error = "Unsupported lyrics format. Use LRC or TXT." });

        try
        {
            await using var stream = file.OpenReadStream();
            var lyricsUrl = await trackService.UploadTrackLyricsAsync(id, stream, file.FileName, file.ContentType);
            return Results.Ok(new { lyricsUrl });
        }
        catch (ArgumentException ex)
        {
            return Results.NotFound(new { error = ex.Message });
        }
    }

    private static async Task<IResult> GetLyrics(Guid id, ITrackService trackService)
    {
        var result = await trackService.GetLyricsStreamAsync(id);
        
        if (result == null)
            return Results.NotFound();

        var (stream, contentType) = result.Value;
        if (stream == null)
            return Results.NotFound();

        return Results.Stream(stream, contentType ?? "text/plain");
    }
}
