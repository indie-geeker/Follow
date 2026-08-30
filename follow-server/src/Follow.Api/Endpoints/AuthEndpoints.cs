using System.Security.Claims;
using Follow.Api.Auth;
using Follow.Api.RateLimiting;
using Follow.Core.Interfaces;
using Follow.Shared.DTOs;

namespace Follow.Api.Endpoints;

public static class AuthEndpoints
{
    public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/auth").WithTags("Authentication");

        group.MapPost("/register", Register)
            .RequireRateLimiting(RateLimitPolicies.Register)
            .AllowAnonymous();
        group.MapPost("/login", Login)
            .RequireRateLimiting(RateLimitPolicies.Login)
            .AllowAnonymous();
        group.MapPost("/refresh", RefreshToken)
            .RequireRateLimiting(RateLimitPolicies.Refresh)
            .AllowAnonymous();
        group.MapPost("/logout", Logout).RequireAuthorization();
        group.MapPost("/logout-all", LogoutAll).RequireAuthorization();
        group.MapGet("/sessions", GetSessions).RequireAuthorization();
        group.MapDelete("/sessions/{id:guid}", RevokeSession).RequireAuthorization();
        group.MapGet("/me", GetCurrentUser).RequireAuthorization();
    }

    private static async Task<IResult> Register(
        RegisterRequest request,
        HttpContext context,
        IAuthService authService,
        AuthCookieManager cookieManager)
    {
        var response = await authService.RegisterAsync(
            request,
            context.Request.Headers.UserAgent.ToString());
        var publicResponse = cookieManager.Apply(context, request.TokenTransport, response);
        return Results.Created(
            $"/api/users/{response.User.Id}",
            ApiResponse<AuthResponse>.Success(publicResponse, "注册成功"));
    }

    private static async Task<IResult> Login(
        LoginRequest request,
        HttpContext context,
        IAuthService authService,
        AuthCookieManager cookieManager)
    {
        var response = await authService.LoginAsync(
            request,
            context.Request.Headers.UserAgent.ToString());
        var publicResponse = cookieManager.Apply(context, request.TokenTransport, response);
        return Results.Ok(ApiResponse<AuthResponse>.Success(publicResponse, "登录成功"));
    }

    private static async Task<IResult> RefreshToken(
        RefreshTokenRequest request,
        HttpContext context,
        IAuthService authService,
        AuthCookieManager cookieManager)
    {
        var resolved = cookieManager.ResolveRefreshToken(context, request);
        var response = await authService.RefreshTokenAsync(
            request with { RefreshToken = resolved.Token, TokenTransport = resolved.Transport });
        var publicResponse = cookieManager.Apply(context, resolved.Transport, response);
        return Results.Ok(ApiResponse<AuthResponse>.Success(publicResponse, "刷新成功"));
    }

    private static async Task<IResult> Logout(
        ClaimsPrincipal principal,
        HttpContext context,
        IAuthService authService,
        AuthCookieManager cookieManager)
    {
        if (!TryGetIdentity(principal, out var userId, out var sessionId))
            throw new UnauthorizedAccessException("无效的登录会话");

        await authService.LogoutAsync(userId, sessionId);
        cookieManager.Clear(context);
        return Results.Ok(ApiResponse.Success("退出成功"));
    }

    private static async Task<IResult> LogoutAll(
        ClaimsPrincipal principal,
        HttpContext context,
        IAuthService authService,
        AuthCookieManager cookieManager)
    {
        if (!TryGetIdentity(principal, out var userId, out _))
            throw new UnauthorizedAccessException("无效的登录会话");

        await authService.LogoutAllAsync(userId);
        cookieManager.Clear(context);
        return Results.Ok(ApiResponse.Success("已退出所有设备"));
    }

    private static async Task<IResult> GetSessions(
        ClaimsPrincipal principal,
        IAuthService authService)
    {
        if (!TryGetIdentity(principal, out var userId, out var sessionId))
            throw new UnauthorizedAccessException("无效的登录会话");

        var sessions = await authService.GetSessionsAsync(userId, sessionId);
        return Results.Ok(ApiResponse<List<SessionDto>>.Success(sessions));
    }

    private static async Task<IResult> RevokeSession(
        Guid id,
        ClaimsPrincipal principal,
        HttpContext context,
        IAuthService authService,
        AuthCookieManager cookieManager)
    {
        if (!TryGetIdentity(principal, out var userId, out var currentSessionId))
            throw new UnauthorizedAccessException("无效的登录会话");

        if (!await authService.RevokeSessionAsync(userId, id))
            return Results.NotFound(ApiResponse.Error(404, "会话不存在"));

        if (id == currentSessionId) cookieManager.Clear(context);
        return Results.NoContent();
    }

    private static async Task<IResult> GetCurrentUser(
        ClaimsPrincipal principal,
        IAuthService authService)
    {
        if (!TryGetIdentity(principal, out var userId, out _))
            throw new UnauthorizedAccessException("无效的登录会话");

        var user = await authService.GetUserByIdAsync(userId);
        if (user == null)
            return Results.NotFound(ApiResponse.Error(404, "用户不存在"));

        var userDto = new UserDto(
            user.Id,
            user.Username,
            user.Email,
            user.Role.ToString(),
            user.AvatarUrl,
            user.CreatedAt);
        return Results.Ok(ApiResponse<UserDto>.Success(userDto));
    }

    private static bool TryGetIdentity(
        ClaimsPrincipal principal,
        out Guid userId,
        out Guid sessionId)
    {
        userId = Guid.Empty;
        sessionId = Guid.Empty;
        return Guid.TryParse(
                   principal.FindFirstValue(ClaimTypes.NameIdentifier),
                   out userId) &&
               Guid.TryParse(principal.FindFirstValue("sid"), out sessionId);
    }
}
