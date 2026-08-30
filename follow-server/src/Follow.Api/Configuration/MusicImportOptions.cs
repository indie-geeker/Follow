using Follow.Infrastructure.Services;

namespace Follow.Api.Configuration;

public sealed class MusicImportOptions
{
    public const string SectionName = "MusicImport";

    public bool Enabled { get; set; }
    public string SourceRoot { get; set; } = string.Empty;
    public string SourceAlias { get; set; } = "只读挂载的音乐目录";
    public long MaximumFileBytes { get; set; } = 2L * 1024 * 1024 * 1024;
    public int MaximumRelativePathLength { get; set; } = 1024;
    public int ScanBatchSize { get; set; } = 500;
    public int ProcessingConcurrency { get; set; } = 1;
    public int LeaseMinutes { get; set; } = 15;

    public MusicImportRuntimeSettings ToRuntimeSettings()
    {
        var sourceRoot = SourceRoot.Trim();
        var sourceAlias = SourceAlias.Trim();
        if (Enabled && string.IsNullOrWhiteSpace(SourceRoot))
            throw new InvalidOperationException("MusicImport:SourceRoot is required when import is enabled.");
        if (Enabled && !Path.IsPathFullyQualified(sourceRoot))
            throw new InvalidOperationException("MusicImport:SourceRoot must be an absolute server path.");
        if (Enabled)
        {
            sourceRoot = Path.GetFullPath(sourceRoot);
            var filesystemRoot = Path.GetPathRoot(sourceRoot);
            if (!string.IsNullOrEmpty(filesystemRoot) && string.Equals(
                    Path.TrimEndingDirectorySeparator(sourceRoot),
                    Path.TrimEndingDirectorySeparator(filesystemRoot),
                    OperatingSystem.IsWindows()
                        ? StringComparison.OrdinalIgnoreCase
                        : StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    "MusicImport:SourceRoot cannot be a filesystem root.");
            }
        }
        if (sourceAlias.Length is < 1 or > 128 ||
            sourceAlias.Contains('/') ||
            sourceAlias.Contains('\\') ||
            sourceAlias.Any(char.IsControl))
        {
            throw new InvalidOperationException(
                "MusicImport:SourceAlias must contain 1 to 128 display characters without path separators or controls.");
        }
        if (MaximumFileBytes < 1)
            throw new InvalidOperationException("MusicImport:MaximumFileBytes must be positive.");
        if (MaximumRelativePathLength is < 1 or > 1024)
            throw new InvalidOperationException("MusicImport:MaximumRelativePathLength must be between 1 and 1024.");
        if (ScanBatchSize is < 1 or > 1000)
            throw new InvalidOperationException("MusicImport:ScanBatchSize must be between 1 and 1000.");
        if (ProcessingConcurrency != 1)
            throw new InvalidOperationException("MusicImport:ProcessingConcurrency must remain 1 until the PostgreSQL concurrency gate is qualified.");
        if (LeaseMinutes is < 1 or > 120)
            throw new InvalidOperationException("MusicImport:LeaseMinutes must be between 1 and 120.");

        return new MusicImportRuntimeSettings
        {
            Enabled = Enabled,
            SourceRoot = sourceRoot,
            SourceAlias = sourceAlias,
            MaximumFileBytes = MaximumFileBytes,
            MaximumRelativePathLength = MaximumRelativePathLength,
            ScanBatchSize = ScanBatchSize,
            ProcessingConcurrency = ProcessingConcurrency,
            LeaseDuration = TimeSpan.FromMinutes(LeaseMinutes)
        };
    }
}
