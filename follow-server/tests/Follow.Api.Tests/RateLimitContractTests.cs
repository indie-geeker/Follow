using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using Follow.Api.RateLimiting;
using Follow.Api.Security;
using Follow.Shared.DTOs;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Follow.Api.Tests;

public class RateLimitContractTests
{
    [Fact]
    public async Task LoginPolicy_ReturnsStandard429WithRetryAfter()
    {
        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseUrls("http://127.0.0.1:0");
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["RateLimiting:Login:PermitLimit"] = "1",
            ["RateLimiting:Login:WindowSeconds"] = "60"
        });
        builder.Services.AddFollowRateLimiting(builder.Configuration);
        await using var app = builder.Build();
        app.UseRateLimiter();
        app.MapGet("/login", () => Results.Ok())
            .RequireRateLimiting(RateLimitPolicies.Login);
        await app.StartAsync();

        var address = app.Services.GetRequiredService<IServer>()
            .Features.Get<IServerAddressesFeature>()!
            .Addresses.Single();
        using var client = new HttpClient { BaseAddress = new Uri(address) };

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/login")).StatusCode);
        var rejected = await client.GetAsync("/login");

        Assert.Equal(HttpStatusCode.TooManyRequests, rejected.StatusCode);
        Assert.True(rejected.Headers.Contains("Retry-After"));
        var body = await rejected.Content.ReadFromJsonAsync<ApiResponse>();
        Assert.NotNull(body);
        Assert.Equal(429, body.Code);
        await app.StopAsync();
    }

    [Fact]
    public async Task GlobalApiPolicy_LimitsOrdinaryApiEndpoint()
    {
        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseUrls("http://127.0.0.1:0");
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["RateLimiting:Api:PermitLimit"] = "1",
            ["RateLimiting:Api:WindowSeconds"] = "60"
        });
        builder.Services.AddFollowRateLimiting(builder.Configuration);
        await using var app = builder.Build();
        app.UseRateLimiter();
        app.MapGet("/api/profile", () => Results.Ok());
        await app.StartAsync();

        var address = app.Services.GetRequiredService<IServer>()
            .Features.Get<IServerAddressesFeature>()!
            .Addresses.Single();
        using var client = new HttpClient { BaseAddress = new Uri(address) };

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/profile")).StatusCode);
        Assert.Equal(
            HttpStatusCode.TooManyRequests,
            (await client.GetAsync("/api/profile")).StatusCode);
        await app.StopAsync();
    }

    [Fact]
    public void PartitionKey_UsesUserIdBeforeRemoteAddress()
    {
        var userId = Guid.NewGuid();
        var first = new DefaultHttpContext();
        first.Connection.RemoteIpAddress = IPAddress.Parse("192.0.2.10");
        first.User = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim(ClaimTypes.NameIdentifier, userId.ToString())],
            "test"));
        var second = new DefaultHttpContext();
        second.Connection.RemoteIpAddress = IPAddress.Parse("192.0.2.11");
        second.User = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim(ClaimTypes.NameIdentifier, userId.ToString())],
            "test"));

        Assert.Equal(
            RateLimitPartitionKey.ForUserOrIp(first),
            RateLimitPartitionKey.ForUserOrIp(second));

        var anonymous = new DefaultHttpContext();
        anonymous.Connection.RemoteIpAddress = IPAddress.Parse("192.0.2.10");
        Assert.NotEqual(
            RateLimitPartitionKey.ForUserOrIp(first),
            RateLimitPartitionKey.ForUserOrIp(anonymous));
    }

    [Fact]
    public void TrackEndpoints_ApplyUploadAndStreamPolicies()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Api/Endpoints/TrackEndpoints.cs"));

        Assert.Contains("RateLimitPolicies.Upload", source);
        Assert.Contains("RateLimitPolicies.Stream", source);
    }

    [Fact]
    public async Task TrustedProxy_UpdatesIpPartitionKeyFromForwardedFor()
    {
        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseUrls("http://127.0.0.1:0");
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ForwardedHeaders:KnownProxies:0"] = "127.0.0.1",
            ["ForwardedHeaders:KnownProxies:1"] = "::1"
        });
        await using var app = builder.Build();
        app.UseFollowForwardedHeaders(builder.Configuration);
        app.MapGet("/partition", (HttpContext context) =>
            RateLimitPartitionKey.ForIp(context));
        await app.StartAsync();

        var address = app.Services.GetRequiredService<IServer>()
            .Features.Get<IServerAddressesFeature>()!
            .Addresses.Single();
        using var client = new HttpClient { BaseAddress = new Uri(address) };
        client.DefaultRequestHeaders.Add("X-Forwarded-For", "198.51.100.42");

        Assert.Equal("ip:198.51.100.42", await client.GetStringAsync("/partition"));
        await app.StopAsync();
    }

    [Fact]
    public void TrustedDockerNetwork_AcceptsOnlyConfiguredCidr()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ForwardedHeaders:KnownNetworks:0"] = "172.16.0.0/12"
            })
            .Build();

        var options = ForwardedHeadersConfiguration.CreateOptions(configuration);

        Assert.Contains(options.KnownIPNetworks, network =>
            network.Contains(IPAddress.Parse("172.31.255.254")));
        Assert.DoesNotContain(options.KnownIPNetworks, network =>
            network.Contains(IPAddress.Parse("192.168.1.10")));
    }

    [Fact]
    public void ProductionProxyOverride_DoesNotRetainArrayEntriesFromAppSettings()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var configuration = new ConfigurationBuilder()
            .AddJsonFile(Path.Combine(serverRoot, "src/Follow.Api/appsettings.json"))
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ForwardedHeaders:KnownProxies:0"] = "172.30.250.2"
            })
            .Build();

        var options = ForwardedHeadersConfiguration.CreateOptions(configuration);

        Assert.Equal(
            [IPAddress.Parse("172.30.250.2")],
            options.KnownProxies);
    }

    [Fact]
    public void Program_DoesNotAllowArbitraryCorsOrigins()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(serverRoot, "src/Follow.Api/Program.cs"));

        Assert.DoesNotContain("AllowAnyOrigin", source);
        Assert.DoesNotContain("AllowAll", source);
    }
}
