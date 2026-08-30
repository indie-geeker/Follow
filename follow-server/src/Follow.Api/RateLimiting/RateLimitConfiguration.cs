using System.Security.Claims;
using System.Threading.RateLimiting;
using Follow.Shared.DTOs;
using Microsoft.AspNetCore.RateLimiting;

namespace Follow.Api.RateLimiting;

public static class RateLimitPolicies
{
    public const string Register = "register";
    public const string Login = "login";
    public const string Refresh = "refresh";
    public const string Api = "api";
    public const string Upload = "upload";
    public const string Stream = "stream";
}

public static class RateLimitPartitionKey
{
    public static string ForIp(HttpContext context) =>
        $"ip:{context.Connection.RemoteIpAddress?.ToString() ?? "unknown"}";

    public static string ForUserOrIp(HttpContext context)
    {
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        return string.IsNullOrWhiteSpace(userId)
            ? ForIp(context)
            : $"user:{userId}";
    }
}

public static class RateLimitConfiguration
{
    public static IServiceCollection AddFollowRateLimiting(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            var apiPermitLimit = configuration.GetValue(
                "RateLimiting:Api:PermitLimit",
                120);
            var apiWindowSeconds = configuration.GetValue(
                "RateLimiting:Api:WindowSeconds",
                60);
            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
                context.Request.Path.StartsWithSegments("/api")
                    ? RateLimitPartition.GetFixedWindowLimiter(
                        RateLimitPartitionKey.ForUserOrIp(context),
                        _ => new FixedWindowRateLimiterOptions
                        {
                            PermitLimit = apiPermitLimit,
                            Window = TimeSpan.FromSeconds(apiWindowSeconds),
                            QueueLimit = 0,
                            QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                            AutoReplenishment = true
                        })
                    : RateLimitPartition.GetNoLimiter("non-api"));
            options.OnRejected = async (context, cancellationToken) =>
            {
                var response = context.HttpContext.Response;
                response.StatusCode = StatusCodes.Status429TooManyRequests;
                response.ContentType = "application/json";
                if (context.Lease.TryGetMetadata(
                        MetadataName.RetryAfter,
                        out var retryAfter))
                {
                    response.Headers.RetryAfter = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds))
                        .ToString();
                }
                else
                {
                    response.Headers.RetryAfter = "1";
                }

                await response.WriteAsJsonAsync(
                    ApiResponse.Error(429, "请求过于频繁，请稍后重试"),
                    cancellationToken);
            };

            AddFixedWindowPolicy(
                options,
                RateLimitPolicies.Register,
                configuration,
                "Register",
                3,
                3600,
                RateLimitPartitionKey.ForIp);
            AddFixedWindowPolicy(
                options,
                RateLimitPolicies.Login,
                configuration,
                "Login",
                5,
                60,
                RateLimitPartitionKey.ForIp);
            AddFixedWindowPolicy(
                options,
                RateLimitPolicies.Refresh,
                configuration,
                "Refresh",
                10,
                60,
                RateLimitPartitionKey.ForIp);
            AddFixedWindowPolicy(
                options,
                RateLimitPolicies.Api,
                configuration,
                "Api",
                120,
                60,
                RateLimitPartitionKey.ForUserOrIp);
            AddFixedWindowPolicy(
                options,
                RateLimitPolicies.Upload,
                configuration,
                "Upload",
                20,
                3600,
                RateLimitPartitionKey.ForUserOrIp);

            var streamLimit = configuration.GetValue(
                "RateLimiting:Stream:PermitLimit",
                3);
            options.AddPolicy(RateLimitPolicies.Stream, context =>
                RateLimitPartition.GetConcurrencyLimiter(
                    RateLimitPartitionKey.ForUserOrIp(context),
                    _ => new ConcurrencyLimiterOptions
                    {
                        PermitLimit = streamLimit,
                        QueueLimit = 0,
                        QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                    }));
        });

        return services;
    }

    private static void AddFixedWindowPolicy(
        RateLimiterOptions options,
        string policyName,
        IConfiguration configuration,
        string sectionName,
        int defaultPermitLimit,
        int defaultWindowSeconds,
        Func<HttpContext, string> partitionKey)
    {
        var permitLimit = configuration.GetValue(
            $"RateLimiting:{sectionName}:PermitLimit",
            defaultPermitLimit);
        var windowSeconds = configuration.GetValue(
            $"RateLimiting:{sectionName}:WindowSeconds",
            defaultWindowSeconds);

        options.AddPolicy(policyName, context =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey(context),
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = permitLimit,
                    Window = TimeSpan.FromSeconds(windowSeconds),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                    AutoReplenishment = true
                }));
    }
}
