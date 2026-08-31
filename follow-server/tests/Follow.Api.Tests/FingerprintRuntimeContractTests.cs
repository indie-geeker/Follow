using System.Text.Json;

namespace Follow.Api.Tests;

public sealed class FingerprintRuntimeContractTests
{
    private const string ExpectedVersion = "1.6.1";
    private const string Amd64Checksum = "fc16cd37a70168040bc9ceb45f1d4d1216f5a75bc4c9cf8564bea70ac6a45733";
    private const string Arm64Checksum = "7eaf5d655c4aa172ab28e3c870b8bb61dd2c327ac94de145676f88842cf6215a";

    private static readonly string ServerRoot = Path.GetFullPath(Path.Combine(
        AppContext.BaseDirectory,
        "../../../../../"));

    private static readonly string RepositoryRoot = Path.GetFullPath(Path.Combine(
        ServerRoot,
        ".."));

    [Fact]
    public void RuntimeImage_PinsOfficialMultiArchitectureFpcalcAndVerifiesItsChecksum()
    {
        var dockerfile = Read("follow-server/Dockerfile");

        Assert.Contains($"ARG CHROMAPRINT_VERSION={ExpectedVersion}", dockerfile, StringComparison.Ordinal);
        Assert.Contains($"ARG CHROMAPRINT_AMD64_SHA256={Amd64Checksum}", dockerfile, StringComparison.Ordinal);
        Assert.Contains($"ARG CHROMAPRINT_ARM64_SHA256={Arm64Checksum}", dockerfile, StringComparison.Ordinal);
        Assert.Contains("releases/download/v${CHROMAPRINT_VERSION}/chromaprint-fpcalc-${CHROMAPRINT_VERSION}-linux-${fpcalc_arch}.tar.gz", dockerfile, StringComparison.Ordinal);
        Assert.Contains("sha256sum -c -", dockerfile, StringComparison.Ordinal);
        Assert.Contains("org.follow.fpcalc.version=\"${CHROMAPRINT_VERSION}\"", dockerfile, StringComparison.Ordinal);
        Assert.Contains("fpcalc -version", dockerfile, StringComparison.Ordinal);
        Assert.Contains("CMD [\"dotnet\", \"Follow.Api.dll\"]", dockerfile, StringComparison.Ordinal);
        Assert.DoesNotContain("ENTRYPOINT [\"dotnet\", \"Follow.Api.dll\"]", dockerfile, StringComparison.Ordinal);
    }

    [Fact]
    public void RuntimeImage_ProvidesAndChecksTheFfmpegDecoderRuntime()
    {
        var dockerfile = Read("follow-server/Dockerfile");

        Assert.Matches(@"ffmpeg=[^\s\\]+", dockerfile);
        Assert.Contains("ffmpeg -version", dockerfile, StringComparison.Ordinal);
    }

    [Fact]
    public void FingerprintLimitsAndExactRuntimeVersion_AreExplicit()
    {
        using var document = JsonDocument.Parse(Read("follow-server/src/Follow.Api/appsettings.json"));
        var fingerprint = document.RootElement.GetProperty("AudioFingerprint");

        Assert.Equal("fpcalc", fingerprint.GetProperty("ExecutablePath").GetString());
        Assert.Equal(ExpectedVersion, fingerprint.GetProperty("RequiredVersionPrefix").GetString());
        Assert.Equal(2, fingerprint.GetProperty("Algorithm").GetInt32());
        Assert.Equal(120, fingerprint.GetProperty("MaximumLengthSeconds").GetInt32());
        Assert.Equal(30, fingerprint.GetProperty("TimeoutSeconds").GetInt32());
        Assert.Equal(2_097_152, fingerprint.GetProperty("MaximumStandardOutputBytes").GetInt32());
        Assert.Equal(16_384, fingerprint.GetProperty("MaximumStandardErrorBytes").GetInt32());
    }

    [Fact]
    public void ReadinessEndpoint_FailsClosedWhenFingerprintRuntimeIsUnavailable()
    {
        var program = Read("follow-server/src/Follow.Api/Program.cs");

        Assert.Contains("/health/ready", program, StringComparison.Ordinal);
        Assert.Contains("AudioFingerprintCapabilityState", program, StringComparison.Ordinal);
        Assert.Contains("Status503ServiceUnavailable", program, StringComparison.Ordinal);
    }

    [Fact]
    public void Compose_UsesExactRuntimeContractAndKeepsSourceMediaReadOnly()
    {
        var compose = Read("docker-compose.yml");
        var importOverlay = Read("docker-compose.import.yml");
        var productionComposePath = Path.Combine(RepositoryRoot, "docker-compose.prod.yml");

        Assert.Contains("AudioFingerprint__ExecutablePath: /usr/local/bin/fpcalc", compose, StringComparison.Ordinal);
        Assert.Contains($"AudioFingerprint__RequiredVersionPrefix: \"{ExpectedVersion}\"", compose, StringComparison.Ordinal);
        Assert.Contains("AudioFingerprint__Algorithm: \"2\"", compose, StringComparison.Ordinal);
        Assert.Contains("AudioFingerprint__MaximumLengthSeconds: \"120\"", compose, StringComparison.Ordinal);
        Assert.Contains("AudioFingerprint__TimeoutSeconds: \"30\"", compose, StringComparison.Ordinal);
        Assert.Contains("AudioFingerprint__MaximumStandardOutputBytes: \"2097152\"", compose, StringComparison.Ordinal);
        Assert.Contains("AudioFingerprint__MaximumStandardErrorBytes: \"16384\"", compose, StringComparison.Ordinal);
        Assert.Contains("http://localhost:5000/health/ready", compose, StringComparison.Ordinal);

        Assert.Contains("read_only: true", importOverlay, StringComparison.Ordinal);
        Assert.Contains("create_host_path: false", importOverlay, StringComparison.Ordinal);
        Assert.True(File.Exists(productionComposePath), "The production Compose contract must exist.");
        Assert.Contains("docker-compose.import.yml", Read("docker-compose.prod.yml"), StringComparison.Ordinal);
    }

    [Fact]
    public void VerificationScriptAndOperatorDocs_CoverRuntimeAndProductionConfiguration()
    {
        var script = Read("scripts/verify-docker-config.sh");
        var serverReadme = Read("follow-server/README.md");
        var repositoryReadmePath = Path.Combine(RepositoryRoot, "README.md");

        Assert.Contains("docker-compose.prod.yml", script, StringComparison.Ordinal);
        Assert.Contains("AudioFingerprint__RequiredVersionPrefix", script, StringComparison.Ordinal);
        Assert.Contains("CHROMAPRINT_AMD64_SHA256", script, StringComparison.Ordinal);
        Assert.Contains("health/ready", script, StringComparison.Ordinal);

        Assert.True(File.Exists(repositoryReadmePath), "The repository runbook must exist.");
        Assert.Contains("fpcalc 1.6.1", File.ReadAllText(repositoryReadmePath), StringComparison.Ordinal);
        Assert.Contains("fpcalc 1.6.1", serverReadme, StringComparison.Ordinal);
        Assert.Contains("health/ready", serverReadme, StringComparison.Ordinal);
        Assert.Contains("只读", serverReadme, StringComparison.Ordinal);
    }

    private static string Read(string repositoryRelativePath) =>
        File.ReadAllText(Path.Combine(RepositoryRoot, repositoryRelativePath));
}
