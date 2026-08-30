using Follow.Api.Uploads;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Follow.Api.Tests;

public class UploadLimitContractTests
{
    [Fact]
    public void MultipartLimit_MatchesFiveHundredMegabyteGatewayContract()
    {
        var services = new ServiceCollection();

        services.AddFollowUploadLimits();

        using var provider = services.BuildServiceProvider();
        var formOptions = provider.GetRequiredService<IOptions<FormOptions>>().Value;
        Assert.Equal(500L * 1024 * 1024, UploadLimitConfiguration.MaxRequestBodyBytes);
        Assert.Equal(UploadLimitConfiguration.MaxRequestBodyBytes, formOptions.MultipartBodyLengthLimit);
    }

    [Fact]
    public void Program_ConfiguresKestrelAndFormUploadLimits()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(serverRoot, "src/Follow.Api/Program.cs"));

        Assert.Contains("ConfigureFollowUploadLimits", source);
        Assert.Contains("AddFollowUploadLimits", source);
    }
}
