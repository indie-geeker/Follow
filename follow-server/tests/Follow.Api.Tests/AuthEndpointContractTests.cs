using System.Text.Json;
using Follow.Api.Auth;
using Follow.Api.Middleware;
using Follow.Shared.DTOs;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;

namespace Follow.Api.Tests;

public class AuthEndpointContractTests
{
    [Fact]
    public void CookieTransport_SetsHttpOnlyCookiesAndHidesTokensFromJson()
    {
        var context = CreateHttpsContext();
        var manager = new AuthCookieManager();
        var response = CreateAuthResponse();

        var publicResponse = manager.Apply(context, "cookie", response);

        Assert.Null(publicResponse.AccessToken);
        Assert.Null(publicResponse.RefreshToken);
        var setCookie = context.Response.Headers.SetCookie.ToString();
        Assert.Contains("follow_access=access-token", setCookie);
        Assert.Contains("follow_refresh=refresh-token", setCookie);
        Assert.Contains("httponly", setCookie, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("secure", setCookie, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("samesite=strict", setCookie, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void CookieTransport_AlwaysMarksCookiesSecure()
    {
        var context = new DefaultHttpContext();
        var manager = new AuthCookieManager();

        manager.Apply(context, "cookie", CreateAuthResponse());

        Assert.Contains(
            "secure",
            context.Response.Headers.SetCookie.ToString(),
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void BodyTransport_ReturnsTokensWithoutCookies()
    {
        var context = CreateHttpsContext();
        var manager = new AuthCookieManager();
        var response = CreateAuthResponse();

        var publicResponse = manager.Apply(context, "body", response);

        Assert.Equal("access-token", publicResponse.AccessToken);
        Assert.Equal("refresh-token", publicResponse.RefreshToken);
        Assert.False(context.Response.Headers.ContainsKey("Set-Cookie"));
    }

    [Fact]
    public void Clear_ExpiresBothAuthenticationCookies()
    {
        var context = CreateHttpsContext();
        var manager = new AuthCookieManager();

        manager.Clear(context);

        var setCookie = context.Response.Headers.SetCookie.ToString();
        Assert.Contains("follow_access=", setCookie);
        Assert.Contains("follow_refresh=", setCookie);
        Assert.Contains("expires=", setCookie, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(typeof(ArgumentException), 400)]
    [InlineData(typeof(UnauthorizedAccessException), 401)]
    [InlineData(typeof(InvalidOperationException), 409)]
    public async Task GlobalExceptionHandler_UsesHttpSemantics(Type exceptionType, int expectedStatus)
    {
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();
        var exception = (Exception)Activator.CreateInstance(exceptionType, "contract failure")!;
        var handler = new GlobalExceptionHandler(NullLogger<GlobalExceptionHandler>.Instance);

        await handler.InvokeAsync(context, _ => throw exception);

        Assert.Equal(expectedStatus, context.Response.StatusCode);
        context.Response.Body.Position = 0;
        var error = await JsonSerializer.DeserializeAsync<ApiResponse>(
            context.Response.Body,
            new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.NotNull(error);
        Assert.Equal(expectedStatus, error.Code);
    }

    [Fact]
    public async Task GlobalExceptionHandler_DoesNotTurnClientCancellationIntoJsonError()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var context = new DefaultHttpContext
        {
            RequestAborted = cancellation.Token
        };
        context.Response.Body = new MemoryStream();
        var handler = new GlobalExceptionHandler(NullLogger<GlobalExceptionHandler>.Instance);

        await handler.InvokeAsync(
            context,
            _ => throw new OperationCanceledException(cancellation.Token));

        Assert.Equal(StatusCodes.Status200OK, context.Response.StatusCode);
        Assert.Empty(((MemoryStream)context.Response.Body).ToArray());
    }

    [Fact]
    public void AuthRoutes_ExposeSessionManagement()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Api/Endpoints/AuthEndpoints.cs"));

        Assert.Contains("/sessions", source);
        Assert.Contains("/logout-all", source);
    }

    [Fact]
    public void LoginRequest_UsesIdentifierInsteadOfLegacyEmailField()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Shared/DTOs/AuthDtos.cs"));
        var loginRequest = source[(source.IndexOf("public record LoginRequest", StringComparison.Ordinal))..];
        loginRequest = loginRequest[..loginRequest.IndexOf("public record RefreshTokenRequest", StringComparison.Ordinal)];

        Assert.Contains("string Identifier", loginRequest);
        Assert.DoesNotContain("string Email", loginRequest);
    }

    private static DefaultHttpContext CreateHttpsContext()
    {
        var context = new DefaultHttpContext();
        context.Request.Scheme = "https";
        return context;
    }

    private static AuthResponse CreateAuthResponse() => new(
        "access-token",
        "refresh-token",
        Guid.NewGuid(),
        DateTime.UtcNow.AddDays(7),
        new UserDto(
            Guid.NewGuid(),
            "member",
            "member@example.com",
            "Member",
            null,
            DateTime.UtcNow));
}
