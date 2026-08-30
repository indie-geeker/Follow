namespace Follow.Core.Services;

public static class MusicImportPathPolicy
{
    public const int DefaultMaximumRelativePathLength = 1024;

    public static ResolvedMusicImportPath Resolve(
        string sourceRoot,
        string relativePath,
        int maximumRelativePathLength = DefaultMaximumRelativePathLength)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(sourceRoot);
        ArgumentOutOfRangeException.ThrowIfLessThan(maximumRelativePathLength, 1);

        var normalizedRelativePath = NormalizeRelativePath(
            relativePath,
            maximumRelativePathLength);
        var normalizedRoot = Path.TrimEndingDirectorySeparator(
            Path.GetFullPath(sourceRoot));
        var fullPath = normalizedRelativePath.Length == 0
            ? normalizedRoot
            : Path.GetFullPath(Path.Combine(
                normalizedRoot,
                Path.Combine(normalizedRelativePath.Split('/'))));

        if (!IsWithinRoot(normalizedRoot, fullPath))
            throw new ArgumentException("Path escapes the configured import root.", nameof(relativePath));

        return new ResolvedMusicImportPath(fullPath, normalizedRelativePath);
    }

    public static string NormalizeRelativePath(
        string relativePath,
        int maximumRelativePathLength = DefaultMaximumRelativePathLength)
    {
        ArgumentNullException.ThrowIfNull(relativePath);
        ArgumentOutOfRangeException.ThrowIfLessThan(maximumRelativePathLength, 1);

        if (Path.IsPathRooted(relativePath) ||
            relativePath.Contains('\\') ||
            relativePath.Any(char.IsControl))
        {
            throw new ArgumentException("Import path must be a safe relative path.", nameof(relativePath));
        }

        var segments = relativePath
            .Split('/', StringSplitOptions.RemoveEmptyEntries)
            .Where(segment => segment != ".")
            .ToArray();
        if (segments.Any(segment => segment == ".."))
            throw new ArgumentException("Parent path traversal is not allowed.", nameof(relativePath));

        var normalized = string.Join('/', segments);
        if (normalized.Length > maximumRelativePathLength)
        {
            throw new ArgumentException(
                $"Import path exceeds {maximumRelativePathLength} characters.",
                nameof(relativePath));
        }

        return normalized;
    }

    public static bool IsReparsePoint(FileSystemInfo entry)
    {
        ArgumentNullException.ThrowIfNull(entry);
        return entry.LinkTarget != null ||
            (entry.Attributes & FileAttributes.ReparsePoint) != 0;
    }

    private static bool IsWithinRoot(string root, string candidate)
    {
        var comparison = OperatingSystem.IsWindows()
            ? StringComparison.OrdinalIgnoreCase
            : StringComparison.Ordinal;
        if (string.Equals(root, candidate, comparison)) return true;

        var rootWithSeparator = root + Path.DirectorySeparatorChar;
        return candidate.StartsWith(rootWithSeparator, comparison);
    }
}

public sealed record ResolvedMusicImportPath(
    string FullPath,
    string RelativePath);
