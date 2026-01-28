using Follow.Core.Interfaces;
using Follow.Shared.Constants;

namespace Follow.Api.Endpoints;

public static class TagEndpoints
{
    public static void MapTagEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/tags").WithTags("Tags");

        // Public endpoints (authenticated users)
        group.MapGet("/", GetTags)
            .WithName("GetTags")
            .WithDescription("Get all tags, optionally filtered by category")
            .RequireAuthorization();

        group.MapGet("/{id:guid}", GetTagById)
            .WithName("GetTagById")
            .WithDescription("Get a tag by ID")
            .RequireAuthorization();

        group.MapGet("/{id:guid}/tracks", GetTracksByTag)
            .WithName("GetTracksByTag")
            .WithDescription("Get tracks associated with a tag")
            .RequireAuthorization();

        // Admin endpoints
        group.MapPost("/", CreateTag)
            .WithName("CreateTag")
            .WithDescription("Create a new tag (Admin only)")
            .RequireAuthorization(Policies.AdminOnly);

        group.MapPut("/{id:guid}", UpdateTag)
            .WithName("UpdateTag")
            .WithDescription("Update a tag (Admin only)")
            .RequireAuthorization(Policies.AdminOnly);

        group.MapDelete("/{id:guid}", DeleteTag)
            .WithName("DeleteTag")
            .WithDescription("Delete a tag (Admin only)")
            .RequireAuthorization(Policies.AdminOnly);
    }

    private static async Task<IResult> GetTags(
        ITagService tagService,
        string? category = null)
    {
        var tags = await tagService.GetTagsAsync(category);
        return Results.Ok(tags);
    }

    private static async Task<IResult> GetTagById(
        Guid id,
        ITagService tagService)
    {
        var tag = await tagService.GetTagByIdAsync(id);
        return tag == null ? Results.NotFound() : Results.Ok(tag);
    }

    private static async Task<IResult> GetTracksByTag(
        Guid id,
        ITagService tagService,
        int page = 1,
        int pageSize = 20)
    {
        var (tracks, totalCount) = await tagService.GetTracksByTagAsync(id, page, pageSize);
        return Results.Ok(new
        {
            tracks,
            totalCount,
            page,
            pageSize,
            totalPages = (int)Math.Ceiling((double)totalCount / pageSize)
        });
    }

    private static async Task<IResult> CreateTag(
        CreateTagRequest request,
        ITagService tagService)
    {
        var tag = await tagService.CreateTagAsync(request);
        return Results.Created($"/api/tags/{tag.Id}", tag);
    }

    private static async Task<IResult> UpdateTag(
        Guid id,
        UpdateTagRequest request,
        ITagService tagService)
    {
        var tag = await tagService.UpdateTagAsync(id, request);
        return tag == null ? Results.NotFound() : Results.Ok(tag);
    }

    private static async Task<IResult> DeleteTag(
        Guid id,
        ITagService tagService)
    {
        var success = await tagService.DeleteTagAsync(id);
        return success ? Results.NoContent() : Results.NotFound();
    }
}
