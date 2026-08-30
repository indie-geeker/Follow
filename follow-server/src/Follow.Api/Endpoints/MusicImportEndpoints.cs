using System.Security.Claims;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Services;
using Follow.Infrastructure.Services;
using Follow.Shared.Constants;
using Follow.Shared.DTOs;

namespace Follow.Api.Endpoints;

public static class MusicImportEndpoints
{
    public static void MapMusicImportEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/admin")
            .WithTags("Music Imports")
            .RequireAuthorization(Policies.AdminOnly);

        group.MapPost("/music-imports", CreateBatch).WithName("CreateMusicImport");
        group.MapGet("/music-imports", GetBatches).WithName("GetMusicImports");
        group.MapGet("/music-imports/capabilities", GetCapabilities).WithName("GetMusicImportCapabilities");
        group.MapGet("/music-imports/{id:guid}", GetBatch).WithName("GetMusicImport");
        group.MapGet("/music-imports/{id:guid}/items", GetItems).WithName("GetMusicImportItems");
        group.MapPost("/music-imports/{id:guid}/start", Start).WithName("StartMusicImport");
        group.MapPost("/music-imports/{id:guid}/pause", Pause).WithName("PauseMusicImport");
        group.MapPost("/music-imports/{id:guid}/resume", Resume).WithName("ResumeMusicImport");
        group.MapPost("/music-imports/{id:guid}/cancel", Cancel).WithName("CancelMusicImport");
        group.MapPost("/music-imports/{id:guid}/retry-failures", RetryFailures)
            .WithName("RetryMusicImportFailures");
    }

    private static async Task<IResult> CreateBatch(
        CreateMusicImportRequest request,
        ClaimsPrincipal principal,
        IMusicImportService service,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(
                principal.FindFirstValue(ClaimTypes.NameIdentifier),
                out var userId))
            return Results.Unauthorized();

        var batch = await service.CreateBatchAsync(userId, request, cancellationToken);
        return Results.Created($"/api/admin/music-imports/{batch.Id}", batch);
    }

    private static async Task<IResult> GetBatches(
        IMusicImportService service,
        int page = 1,
        int pageSize = 20,
        string? status = null,
        CancellationToken cancellationToken = default)
    {
        if (!TryParseStatus(status, out MusicImportBatchStatus? parsedStatus))
            return Results.BadRequest(ApiResponse.Error(400, "Invalid import batch status."));
        return Results.Ok(await service.GetBatchesAsync(
            page,
            pageSize,
            parsedStatus,
            cancellationToken));
    }

    private static IResult GetCapabilities(MusicImportRuntimeSettings settings)
    {
        var sourceAvailable = false;
        if (settings.Enabled)
        {
            try
            {
                var source = new DirectoryInfo(settings.SourceRoot);
                sourceAvailable = source.Exists && !MusicImportPathPolicy.IsReparsePoint(source);
            }
            catch
            {
                sourceAvailable = false;
            }
        }

        return Results.Ok(new MusicImportCapabilitiesDto(
            settings.Enabled,
            sourceAvailable,
            settings.SourceAlias,
            settings.ProcessingConcurrency));
    }

    private static async Task<IResult> GetBatch(
        Guid id,
        IMusicImportService service,
        CancellationToken cancellationToken)
    {
        var batch = await service.GetBatchAsync(id, cancellationToken);
        return batch == null ? Results.NotFound() : Results.Ok(batch);
    }

    private static async Task<IResult> GetItems(
        Guid id,
        IMusicImportService service,
        int page = 1,
        int pageSize = 50,
        string? status = null,
        CancellationToken cancellationToken = default)
    {
        if (!TryParseStatus(status, out MusicImportItemStatus? parsedStatus))
            return Results.BadRequest(ApiResponse.Error(400, "Invalid import item status."));
        var items = await service.GetItemsAsync(
            id,
            page,
            pageSize,
            parsedStatus,
            cancellationToken);
        return items == null ? Results.NotFound() : Results.Ok(items);
    }

    private static Task<IResult> Start(
        Guid id,
        IMusicImportService service,
        CancellationToken cancellationToken) =>
        ExecuteAction(service.StartAsync(id, cancellationToken));

    private static Task<IResult> Pause(
        Guid id,
        IMusicImportService service,
        CancellationToken cancellationToken) =>
        ExecuteAction(service.PauseAsync(id, cancellationToken));

    private static Task<IResult> Resume(
        Guid id,
        IMusicImportService service,
        CancellationToken cancellationToken) =>
        ExecuteAction(service.ResumeAsync(id, cancellationToken));

    private static Task<IResult> Cancel(
        Guid id,
        IMusicImportService service,
        CancellationToken cancellationToken) =>
        ExecuteAction(service.CancelAsync(id, cancellationToken));

    private static Task<IResult> RetryFailures(
        Guid id,
        IMusicImportService service,
        CancellationToken cancellationToken) =>
        ExecuteAction(service.RetryFailuresAsync(id, cancellationToken));

    private static async Task<IResult> ExecuteAction(
        Task<MusicImportBatchDto?> action)
    {
        var batch = await action;
        return batch == null ? Results.NotFound() : Results.Ok(batch);
    }

    private static bool TryParseStatus<TStatus>(
        string? value,
        out TStatus? status)
        where TStatus : struct, Enum
    {
        status = null;
        if (string.IsNullOrWhiteSpace(value)) return true;
        if (int.TryParse(value, out _) ||
            !Enum.TryParse<TStatus>(value, ignoreCase: true, out var parsed) ||
            !Enum.IsDefined(parsed))
            return false;
        status = parsed;
        return true;
    }
}
