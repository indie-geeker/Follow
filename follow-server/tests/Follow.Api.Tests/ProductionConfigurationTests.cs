using System.Text.Json;

namespace Follow.Api.Tests;

public class ProductionConfigurationTests
{
    [Fact]
    public void AppSettings_DoesNotShipDatabaseJwtOrObjectStorageCredentials()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        using var document = JsonDocument.Parse(File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Api/appsettings.json")));
        var root = document.RootElement;

        Assert.False(root.GetProperty("ConnectionStrings")
            .TryGetProperty("DefaultConnection", out _));
        Assert.False(root.GetProperty("JwtSettings")
            .TryGetProperty("SecretKey", out _));
        Assert.False(root.GetProperty("MinioSettings")
            .TryGetProperty("AccessKey", out _));
        Assert.False(root.GetProperty("MinioSettings")
            .TryGetProperty("SecretKey", out _));
    }

    [Fact]
    public void Program_FailsClosedWhenRequiredSecretsAreMissing()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(serverRoot, "src/Follow.Api/Program.cs"));

        Assert.Contains("GetRequiredConnectionString", source);
        Assert.Contains("GetRequiredJwtSecret", source);
    }
}
