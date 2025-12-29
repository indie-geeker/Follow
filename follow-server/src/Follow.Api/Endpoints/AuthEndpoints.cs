using System.Security.Claims;
using Follow.Core.Interfaces;
using Follow.Shared.Constants;
using Follow.Shared.DTOs;

namespace Follow.Api.Endpoints;

public static class AuthEndpoints
{
    public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/auth").WithTags("Authentication");

        group.MapPost("/register", Register)
            .WithName("Register")
            .WithDescription("Register a new user. First user becomes Admin.")
            .AllowAnonymous();

        group.MapPost("/login", Login)
            .WithName("Login")
            .WithDescription("Login with email and password")
            .AllowAnonymous();

        group.MapPost("/refresh", RefreshToken)
            .WithName("RefreshToken")
            .WithDescription("Refresh access token using refresh token")
            .AllowAnonymous();

        group.MapPost("/logout", Logout)
            .WithName("Logout")
            .WithDescription("Logout and invalidate refresh token")
            .RequireAuthorization();

        group.MapGet("/me", GetCurrentUser)
            .WithName("GetCurrentUser")
            .WithDescription("Get current authenticated user info")
            .RequireAuthorization();
    }

    private static async Task<IResult> Register(
        RegisterRequest request,
        IAuthService authService)
    {
        try
        {
            var response = await authService.RegisterAsync(request);
            return Results.Created($"/api/users/{response.User.Id}", response);
        }
        catch (InvalidOperationException ex)
        {
            return Results.BadRequest(new { error = ex.Message });
        }
    }

    private static async Task<IResult> Login(
        LoginRequest request,
        IAuthService authService)
    {
        try
        {
            var response = await authService.LoginAsync(request);
            return Results.Ok(response);
        }
        catch (UnauthorizedAccessException)
        {
            return Results.Unauthorized();
        }
    }

    private static async Task<IResult> RefreshToken(
        RefreshTokenRequest request,
        IAuthService authService)
    {
        try
        {
            var response = await authService.RefreshTokenAsync(request);
            return Results.Ok(response);
        }
        catch (UnauthorizedAccessException)
        {
            return Results.Unauthorized();
        }
    }

    private static async Task<IResult> Logout(
        ClaimsPrincipal user,
        IAuthService authService)
    {
        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Results.Unauthorized();
        }

        await authService.LogoutAsync(userId);
        return Results.NoContent();
    }

    private static async Task<IResult> GetCurrentUser(
        ClaimsPrincipal user,
        IAuthService authService)
    {
        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Results.Unauthorized();
        }

        var dbUser = await authService.GetUserByIdAsync(userId);
        if (dbUser == null)
        {
            return Results.NotFound();
        }

        var userDto = new UserDto(
            dbUser.Id,
            dbUser.Username,
            dbUser.Email,
            dbUser.Role.ToString(),
            dbUser.AvatarUrl,
            dbUser.CreatedAt);

        return Results.Ok(userDto);
    }
}
