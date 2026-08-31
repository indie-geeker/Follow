using System.Text.Json;

namespace Follow.Api.Tests;

public class MusicImportConfigurationTests
{
    private static readonly string ServerRoot = Path.GetFullPath(Path.Combine(
        AppContext.BaseDirectory,
        "../../../../../"));

    private static readonly string RepositoryRoot = Path.GetFullPath(Path.Combine(
        ServerRoot,
        ".."));

    [Fact]
    public void BaseConfiguration_DisablesImportAndDoesNotMountSourceLibrary()
    {
        using var document = JsonDocument.Parse(File.ReadAllText(Path.Combine(
            ServerRoot,
            "src/Follow.Api/appsettings.json")));

        var musicImport = document.RootElement.GetProperty("MusicImport");
        Assert.False(musicImport.GetProperty("Enabled").GetBoolean());

        var baseCompose = File.ReadAllText(Path.Combine(
            RepositoryRoot,
            "docker-compose.yml"));

        Assert.DoesNotContain("FOLLOW_IMPORT_SOURCE_PATH", baseCompose, StringComparison.Ordinal);
        Assert.DoesNotContain("/imports", baseCompose, StringComparison.Ordinal);
    }

    [Fact]
    public void BaseConfiguration_DeclaresFailClosedFingerprintRuntimeContract()
    {
        using var document = JsonDocument.Parse(File.ReadAllText(Path.Combine(
            ServerRoot,
            "src/Follow.Api/appsettings.json")));

        var fingerprint = document.RootElement.GetProperty("AudioFingerprint");

        Assert.Equal("fpcalc", fingerprint.GetProperty("ExecutablePath").GetString());
        Assert.Equal(2, fingerprint.GetProperty("Algorithm").GetInt32());
        Assert.Equal(120, fingerprint.GetProperty("MaximumLengthSeconds").GetInt32());
        Assert.True(fingerprint.GetProperty("TimeoutSeconds").GetInt32() > 0);
        Assert.True(fingerprint.GetProperty("MaximumStandardOutputBytes").GetInt32() > 0);
        Assert.True(fingerprint.GetProperty("MaximumStandardErrorBytes").GetInt32() > 0);
        Assert.Equal("1.6.1", fingerprint.GetProperty("RequiredVersionPrefix").GetString());
        Assert.Equal(0.85, fingerprint.GetProperty("CandidateSimilarityThreshold").GetDouble());
        Assert.Equal(0.99, fingerprint.GetProperty("MatchSimilarityThreshold").GetDouble());
        Assert.Equal(0.98, fingerprint.GetProperty("MinimumSegmentSimilarity").GetDouble());
        Assert.Equal(0.85, fingerprint.GetProperty("MinimumCoverageFraction").GetDouble());
        Assert.Equal(2, fingerprint.GetProperty("MaximumDurationDifferenceSeconds").GetInt32());
        Assert.Equal(2, fingerprint.GetProperty("MaximumAlignmentOffsetFrames").GetInt32());
        Assert.Equal(512, fingerprint.GetProperty("MaximumCandidateAlignmentOffsetFrames").GetInt32());
        Assert.Equal(3, fingerprint.GetProperty("SegmentCount").GetInt32());
    }

    [Fact]
    public void ImportOverlay_RequiresReadOnlyExistingSourceBindOnApiService()
    {
        var overlayPath = Path.Combine(RepositoryRoot, "docker-compose.import.yml");
        Assert.True(File.Exists(overlayPath), "The opt-in Compose overlay must exist.");

        var overlay = File.ReadAllText(overlayPath);

        Assert.Contains("services:\n  api:", overlay, StringComparison.Ordinal);
        Assert.DoesNotContain("import-worker:", overlay, StringComparison.Ordinal);
        Assert.Contains("MusicImport__Enabled: \"true\"", overlay, StringComparison.Ordinal);
        Assert.Contains("MusicImport__SourceRoot: /imports/library", overlay, StringComparison.Ordinal);
        Assert.Matches(
            "source:\\s*\\\"?\\$\\{FOLLOW_IMPORT_SOURCE_PATH:\\?[^}]+\\}\\\"?",
            overlay);
        Assert.Matches("target:\\s*/imports/library", overlay);
        Assert.Matches("read_only:\\s*true", overlay);
        Assert.Matches("create_host_path:\\s*false", overlay);
    }

    [Fact]
    public void ImportOperations_DocumentTheOptInSafetyContract()
    {
        var environmentExample = File.ReadAllText(Path.Combine(
            RepositoryRoot,
            ".env.example"));
        var readme = File.ReadAllText(Path.Combine(ServerRoot, "README.md"));

        Assert.Matches(
            "(?m)^# FOLLOW_IMPORT_SOURCE_PATH=/absolute/path/to/music-library$",
            environmentExample);
        Assert.DoesNotMatch("(?m)^FOLLOW_IMPORT_SOURCE_PATH=", environmentExample);
        Assert.Contains("docker-compose.import.yml", readme, StringComparison.Ordinal);
        Assert.Contains("只读", readme, StringComparison.Ordinal);
        Assert.Contains("不会修改或删除源文件", readme, StringComparison.Ordinal);
        Assert.Contains("取消", readme, StringComparison.Ordinal);
        Assert.Contains("幂等", readme, StringComparison.Ordinal);
    }
}
