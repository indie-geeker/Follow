namespace Follow.Infrastructure.Services;

/// <summary>
/// Validated runtime settings shared by import services without exposing the host path in API DTOs.
/// </summary>
public sealed class MusicImportRuntimeSettings
{
    public bool Enabled { get; init; }
    public string SourceRoot { get; init; } = string.Empty;
    public string SourceAlias { get; init; } = "mounted music library";
    public long MaximumFileBytes { get; init; } = 2L * 1024 * 1024 * 1024;
    public int MaximumRelativePathLength { get; init; } = 1024;
    public int ScanBatchSize { get; init; } = 500;
    public int ProcessingConcurrency { get; init; } = 1;
    public TimeSpan LeaseDuration { get; init; } = TimeSpan.FromMinutes(15);
}
