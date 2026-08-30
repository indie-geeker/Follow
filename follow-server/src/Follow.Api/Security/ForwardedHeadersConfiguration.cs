using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

namespace Follow.Api.Security;

public static class ForwardedHeadersConfiguration
{
    public static IApplicationBuilder UseFollowForwardedHeaders(
        this IApplicationBuilder app,
        IConfiguration configuration)
    {
        return app.UseForwardedHeaders(CreateOptions(configuration));
    }

    public static ForwardedHeadersOptions CreateOptions(IConfiguration configuration)
    {
        var options = new ForwardedHeadersOptions
        {
            ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                               ForwardedHeaders.XForwardedProto,
            ForwardLimit = 1
        };
        options.KnownIPNetworks.Clear();
        options.KnownProxies.Clear();

        var configuredProxies = configuration
            .GetSection("ForwardedHeaders:KnownProxies")
            .Get<string[]>() ?? ["127.0.0.1", "::1"];
        foreach (var proxy in configuredProxies)
        {
            if (!IPAddress.TryParse(proxy, out var address))
                throw new InvalidOperationException($"无效的可信代理地址: {proxy}");
            options.KnownProxies.Add(address);
        }

        var configuredNetworks = configuration
            .GetSection("ForwardedHeaders:KnownNetworks")
            .Get<string[]>() ?? [];
        foreach (var network in configuredNetworks)
        {
            try
            {
                options.KnownIPNetworks.Add(System.Net.IPNetwork.Parse(network));
            }
            catch (FormatException exception)
            {
                throw new InvalidOperationException(
                    $"无效的可信代理网络: {network}",
                    exception);
            }
        }

        return options;
    }
}
