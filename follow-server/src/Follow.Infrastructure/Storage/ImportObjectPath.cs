namespace Follow.Infrastructure.Services;

public static class ImportObjectPath
{
    public static string BuildStaging(Guid itemId, string extension)
    {
        var normalizedExtension = extension.ToLowerInvariant();
        if (!normalizedExtension.StartsWith('.') ||
            !AudioFileExtension(normalizedExtension))
        {
            throw new ArgumentException("Unsupported staging extension.", nameof(extension));
        }

        return $"tracks/staging/{itemId:N}/source{normalizedExtension}";
    }

    public static string BuildRevision(
        Guid reviewGroupId,
        int decisionVersion,
        Guid itemId,
        string extension)
    {
        var normalizedExtension = extension.ToLowerInvariant();
        if (decisionVersion < 0 ||
            !normalizedExtension.StartsWith('.') ||
            !AudioFileExtension(normalizedExtension))
        {
            throw new ArgumentException("Invalid managed revision path component.");
        }

        return $"tracks/import/{reviewGroupId:N}/revisions/{decisionVersion}/{itemId:N}{normalizedExtension}";
    }

    public static void Validate(string objectPath)
    {
        ArgumentNullException.ThrowIfNull(objectPath);
        var managedPrefix = objectPath.StartsWith("tracks/import/", StringComparison.Ordinal) ||
            objectPath.StartsWith("tracks/staging/", StringComparison.Ordinal);
        if (!managedPrefix ||
            objectPath.Length > 1024 ||
            objectPath.StartsWith('/') ||
            objectPath.Contains('\\') ||
            objectPath.Contains("//", StringComparison.Ordinal) ||
            objectPath.Any(char.IsControl) ||
            Uri.TryCreate(objectPath, UriKind.Absolute, out _) ||
            objectPath.Split('/').Any(segment => segment is "" or "." or ".."))
        {
            throw new ArgumentException(
                "Object path must be a relative managed key under tracks/import or tracks/staging.",
                nameof(objectPath));
        }
    }

    public static bool IsStaging(string objectPath)
    {
        Validate(objectPath);
        return objectPath.StartsWith("tracks/staging/", StringComparison.Ordinal);
    }

    private static bool AudioFileExtension(string extension) =>
        extension is ".mp3" or ".flac" or ".wav" or ".aac" or ".ogg" or ".m4a";
}
