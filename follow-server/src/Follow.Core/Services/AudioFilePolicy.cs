namespace Follow.Core.Services;

public static class AudioFilePolicy
{
    private static readonly IReadOnlyDictionary<string, string> ContentTypes =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [".mp3"] = "audio/mpeg",
            [".flac"] = "audio/flac",
            [".wav"] = "audio/wav",
            [".aac"] = "audio/aac",
            [".ogg"] = "audio/ogg",
            [".m4a"] = "audio/mp4"
        };

    public static bool TryGetCanonicalContentType(
        string fileName,
        out string contentType)
    {
        ArgumentNullException.ThrowIfNull(fileName);
        return ContentTypes.TryGetValue(Path.GetExtension(fileName), out contentType!);
    }

    public static void ValidateCandidate(
        string relativePath,
        long sizeBytes,
        long maximumFileBytes = long.MaxValue,
        int maximumRelativePathLength = MusicImportPathPolicy.DefaultMaximumRelativePathLength)
    {
        var normalizedPath = MusicImportPathPolicy.NormalizeRelativePath(
            relativePath,
            maximumRelativePathLength);
        if (!TryGetCanonicalContentType(normalizedPath, out _))
            throw new ArgumentException("Unsupported audio format.", nameof(relativePath));
        if (sizeBytes <= 0)
            throw new ArgumentOutOfRangeException(nameof(sizeBytes), "Audio file cannot be empty.");
        if (sizeBytes > maximumFileBytes)
        {
            throw new ArgumentOutOfRangeException(
                nameof(sizeBytes),
                $"Audio file exceeds {maximumFileBytes} bytes.");
        }
    }
}
