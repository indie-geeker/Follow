using Follow.Shared.DTOs;

namespace Follow.Api.Auth;

public sealed class AuthCookieManager
{
    public const string AccessCookieName = "follow_access";
    public const string RefreshCookieName = "follow_refresh";

    public AuthResponse Apply(HttpContext context, string? transport, AuthResponse response)
    {
        var normalized = NormalizeTransport(transport);
        if (normalized == "body") return response;

        if (string.IsNullOrWhiteSpace(response.AccessToken) ||
            string.IsNullOrWhiteSpace(response.RefreshToken))
        {
            throw new InvalidOperationException("认证服务未返回完整令牌");
        }

        context.Response.Cookies.Append(
            AccessCookieName,
            response.AccessToken,
            CreateOptions(context, "/api", expires: null));
        context.Response.Cookies.Append(
            RefreshCookieName,
            response.RefreshToken,
            CreateOptions(context, "/api/auth", response.ExpiresAt));

        return response with { AccessToken = null, RefreshToken = null };
    }

    public (string? Token, string Transport) ResolveRefreshToken(
        HttpContext context,
        RefreshTokenRequest request)
    {
        if (!string.IsNullOrWhiteSpace(request.RefreshToken))
            return (request.RefreshToken, NormalizeTransport(request.TokenTransport));

        return (context.Request.Cookies[RefreshCookieName], "cookie");
    }

    public void Clear(HttpContext context)
    {
        context.Response.Cookies.Delete(
            AccessCookieName,
            CreateOptions(context, "/api", expires: null));
        context.Response.Cookies.Delete(
            RefreshCookieName,
            CreateOptions(context, "/api/auth", expires: null));
    }

    private static CookieOptions CreateOptions(
        HttpContext context,
        string path,
        DateTime? expires)
    {
        return new CookieOptions
        {
            HttpOnly = true,
            Secure = true,
            SameSite = SameSiteMode.Strict,
            Path = path,
            IsEssential = true,
            Expires = expires == null ? null : new DateTimeOffset(expires.Value)
        };
    }

    private static string NormalizeTransport(string? transport)
    {
        var normalized = transport?.Trim().ToLowerInvariant() ?? "body";
        return normalized is "body" or "cookie"
            ? normalized
            : throw new ArgumentException("tokenTransport 必须是 body 或 cookie");
    }
}
