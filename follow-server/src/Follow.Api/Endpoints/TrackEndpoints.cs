using System.Security.Claims;
using Follow.Api.RateLimiting;
using Follow.Api.Media;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Services;
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

        group.MapMethods("/{id:guid}/stream", [HttpMethods.Get, HttpMethods.Head], StreamTrack)
            .WithName("StreamTrack")
            .WithDescription("Stream audio for playback")
            .RequireAuthorization()
            .RequireRateLimiting(RateLimitPolicies.Stream);

        // Admin endpoints
        group.MapPost("/upload", UploadTrack)
            .WithName("UploadTrack")
            .WithDescription("Upload a new track (Admin only)")
            .RequireAuthorization(Policies.AdminOnly)
            .RequireRateLimiting(RateLimitPolicies.Upload)
            .DisableAntiforgery();

        group.MapPost("/{id:guid}/cover", UploadCover)
            .WithName("UploadTrackCover")
            .WithDescription("Upload cover image for a track (Admin only)")
            .RequireAuthorization(Policies.AdminOnly)
            .RequireRateLimiting(RateLimitPolicies.Upload)
            .DisableAntiforgery();

        group.MapPost("/{id:guid}/lyrics", UploadLyrics)
            .WithName("UploadTrackLyrics")
            .WithDescription("Upload lyrics file for a track (Admin only)")
            .RequireAuthorization(Policies.AdminOnly)
            .RequireRateLimiting(RateLimitPolicies.Upload)
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

        // Tag endpoints
        group.MapGet("/{id:guid}/tags", GetTrackTags)
            .WithName("GetTrackTags")
            .WithDescription("Get all tags for a track")
            .RequireAuthorization();

        group.MapPut("/{id:guid}/tags", SetTrackTags)
            .WithName("SetTrackTags")
            .WithDescription("Set tags for a track (Admin only)")
            .RequireAuthorization(Policies.AdminOnly);

        // Cover image endpoint
        group.MapGet("/cover/{*path}", GetCoverImage)
            .WithName("GetCoverImage")
            .WithDescription("Get cover image by path")
            .AllowAnonymous();
    }

    private static async Task<IResult> GetTracks(
        ITrackService trackService,
        int page = 1,
        int pageSize = 20,
        string? search = null,
        Guid? artistId = null,
        Guid? albumId = null)
    {
        var (tracks, totalCount) = await trackService.GetTracksAsync(page, pageSize, search, artistId, albumId);
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

    private static async Task<IResult> StreamTrack(
        Guid id,
        ITrackService trackService,
        IStorageService storageService)
    {
        var storedObject = await trackService.GetTrackObjectAsync(id);
        if (storedObject == null)
            return Results.NotFound();
        return new StorageObjectResult(
            storageService,
            storedObject.Path,
            storedObject.ContentType);
    }

    public static async Task<IResult> UploadTrack(
        IFormFile file,
        string? clientRequestId,
        ClaimsPrincipal principal,
        IMusicImportService importService,
        MusicImportRuntimeSettings settings,
        AudioFingerprintCapabilityState fingerprintCapability,
        CancellationToken cancellationToken)
    {
        if (!fingerprintCapability.CanIngest(settings.Enabled))
        {
            return Results.Json(
                new
                {
                    code = fingerprintCapability.Current.ErrorCode ?? "FINGERPRINT_UNAVAILABLE",
                    message = "Acoustic fingerprint analysis is unavailable; upload was not accepted."
                },
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }
        if (!Guid.TryParse(
                principal.FindFirstValue(ClaimTypes.NameIdentifier),
                out var userId))
        {
            return Results.Unauthorized();
        }
        if (file.Length == 0)
            return Results.BadRequest(new { error = "No file uploaded" });

        var allowedExtensions = new[] { ".mp3", ".flac", ".wav", ".aac", ".ogg", ".m4a" };
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        
        if (!allowedExtensions.Contains(extension))
            return Results.BadRequest(new { error = "Unsupported audio format" });

        await using var stream = file.OpenReadStream();
        var accepted = await importService.CreateBrowserUploadAsync(
            userId,
            new BrowserMusicImportUpload(
                stream,
                file.FileName,
                file.ContentType,
                file.Length,
                string.IsNullOrWhiteSpace(clientRequestId)
                    ? Guid.NewGuid().ToString("N")
                    : clientRequestId),
            cancellationToken);
        return Results.Accepted(
            $"/api/admin/music-imports/{accepted.BatchId}",
            accepted);
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

    private static async Task<IResult> GetLyrics(
        Guid id,
        ITrackService trackService,
        IStorageService storageService)
    {
        var storedObject = await trackService.GetLyricsObjectAsync(id);
        if (storedObject == null)
            return Results.NotFound();
        return new StorageObjectResult(
            storageService,
            storedObject.Path,
            storedObject.ContentType);
    }

    private static async Task<IResult> GetTrackTags(Guid id, ITrackService trackService)
    {
        var tags = await trackService.GetTrackTagsAsync(id);
        return Results.Ok(tags);
    }

    private static async Task<IResult> SetTrackTags(
        Guid id,
        SetTrackTagsRequest request,
        ITrackService trackService)
    {
        var success = await trackService.SetTrackTagsAsync(id, request.TagIds);
        return success ? Results.Ok() : Results.NotFound();
    }

    private static async Task<IResult> GetCoverImage(
        string path,
        IStorageService storageService)
    {
        if (!MediaPathPolicy.AllowsAnonymousCover(path))
            return Results.NotFound();

        var contentType = Path.GetExtension(path).ToLowerInvariant() switch
        {
            ".jpg" or ".jpeg" => "image/jpeg",
            ".png" => "image/png",
            ".webp" => "image/webp",
            ".gif" => "image/gif",
            _ => "application/octet-stream"
        };
        
        return new StorageObjectResult(storageService, path, contentType);
    }
}

public record SetTrackTagsRequest(List<Guid> TagIds);
