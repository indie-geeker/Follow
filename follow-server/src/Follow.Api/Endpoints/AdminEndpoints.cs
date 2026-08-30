using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Shared.Constants;
using Follow.Shared.DTOs;

namespace Follow.Api.Endpoints;

public static class AdminEndpoints
{
    public static void MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/admin").WithTags("Admin").RequireAuthorization(Policies.AdminOnly);

        // Dashboard
        group.MapGet("/dashboard", GetDashboardStats)
            .WithName("GetDashboardStats")
            .WithDescription("Get dashboard statistics");

        // User Management
        group.MapPost("/users", CreateUser)
            .WithName("AdminCreateUser")
            .WithDescription("Create or invite a user with an initial password");

        group.MapGet("/users", GetUsers)
            .WithName("AdminGetUsers")
            .WithDescription("Get all users with pagination");

        group.MapGet("/users/{id:guid}", GetUserById)
            .WithName("AdminGetUserById")
            .WithDescription("Get user details");

        group.MapPut("/users/{id:guid}/role", UpdateUserRole)
            .WithName("UpdateUserRole")
            .WithDescription("Update user role");

        group.MapDelete("/users/{id:guid}", DeleteUser)
            .WithName("AdminDeleteUser")
            .WithDescription("Delete a user");
    }

    private static async Task<IResult> GetDashboardStats(IAdminService adminService)
    {
        var stats = await adminService.GetDashboardStatsAsync();
        return Results.Ok(stats);
    }

    private static async Task<IResult> CreateUser(CreateUserRequest request, IAdminService adminService)
    {
        try
        {
            var user = await adminService.CreateUserAsync(request);
            return Results.Created($"/api/admin/users/{user.Id}", user);
        }
        catch (ArgumentException exception)
        {
            return Results.BadRequest(ApiResponse.Error(400, exception.Message));
        }
        catch (InvalidOperationException exception)
        {
            return Results.Conflict(ApiResponse.Error(409, exception.Message));
        }
    }

    private static async Task<IResult> GetUsers(
        IAdminService adminService,
        int page = 1,
        int pageSize = 20,
        string? search = null)
    {
        var (users, totalCount) = await adminService.GetUsersAsync(page, pageSize, search);
        return Results.Ok(new
        {
            users,
            totalCount,
            page,
            pageSize,
            totalPages = (int)Math.Ceiling((double)totalCount / pageSize)
        });
    }

    private static async Task<IResult> GetUserById(Guid id, IAdminService adminService)
    {
        var user = await adminService.GetUserByIdAsync(id);
        return user == null ? Results.NotFound() : Results.Ok(user);
    }

    private static async Task<IResult> UpdateUserRole(Guid id, UpdateRoleRequest request, IAdminService adminService)
    {
        if (!TryParseRole(request.Role, out var role))
            return Results.BadRequest(new { error = "Invalid role" });

        var user = await adminService.UpdateUserRoleAsync(id, role);
        return user == null ? Results.NotFound() : Results.Ok(user);
    }

    public static bool TryParseRole(string? value, out UserRole role)
    {
        role = default;
        return !string.IsNullOrWhiteSpace(value) &&
               !int.TryParse(value, out _) &&
               Enum.TryParse(value, true, out role) &&
               Enum.IsDefined(role);
    }

    private static async Task<IResult> DeleteUser(Guid id, IAdminService adminService)
    {
        var success = await adminService.DeleteUserAsync(id);
        if (!success)
            return Results.BadRequest(new { error = "Cannot delete user. They may be the last admin." });
        
        return Results.NoContent();
    }
}

public record UpdateRoleRequest(string Role);
