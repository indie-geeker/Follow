using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Server.IIS;

namespace Follow.Api.Uploads;

public static class UploadLimitConfiguration
{
    public const long MaxRequestBodyBytes = 500L * 1024 * 1024;

    public static IServiceCollection AddFollowUploadLimits(
        this IServiceCollection services)
    {
        services.Configure<FormOptions>(options =>
            options.MultipartBodyLengthLimit = MaxRequestBodyBytes);
        services.Configure<IISServerOptions>(options =>
            options.MaxRequestBodySize = MaxRequestBodyBytes);
        return services;
    }

    public static IWebHostBuilder ConfigureFollowUploadLimits(
        this IWebHostBuilder webHost)
    {
        webHost.ConfigureKestrel(options =>
            options.Limits.MaxRequestBodySize = MaxRequestBodyBytes);
        return webHost;
    }
}
