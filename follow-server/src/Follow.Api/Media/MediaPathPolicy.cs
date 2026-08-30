namespace Follow.Api.Media;

public static class MediaPathPolicy
{
    private static readonly HashSet<string> ImageExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".webp", ".gif"
    };

    public static bool AllowsAnonymousCover(string? path)
    {
        if (string.IsNullOrWhiteSpace(path) ||
            path.StartsWith('/') ||
            path.Contains("..", StringComparison.Ordinal) ||
            path.Contains('\\'))
        {
            return false;
        }

        var allowedPrefix = path.StartsWith("covers/", StringComparison.OrdinalIgnoreCase) ||
                            path.StartsWith("artists/", StringComparison.OrdinalIgnoreCase) ||
                            path.StartsWith("albums/", StringComparison.OrdinalIgnoreCase);
        return allowedPrefix && ImageExtensions.Contains(Path.GetExtension(path));
    }
}
