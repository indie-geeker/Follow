using System.Text;
using System.Text.RegularExpressions;

namespace Follow.Core.Services;

public static partial class EmbeddedLyricsPolicy
{
    public const int MaxUtf8Bytes = 256 * 1024;

    public static string? Normalize(string? lyrics)
    {
        if (string.IsNullOrWhiteSpace(lyrics) || lyrics.Length > MaxUtf8Bytes)
            return null;

        if (Encoding.UTF8.GetByteCount(lyrics) > MaxUtf8Bytes)
            return null;

        var normalized = lyrics
            .Replace("\r\n", "\n", StringComparison.Ordinal)
            .Replace('\r', '\n')
            .Trim('\uFEFF', ' ', '\t', '\n');

        return TimedLinePattern().IsMatch(normalized) ? normalized : null;
    }

    [GeneratedRegex(@"(?m)^\s*\[\d{2}:\d{2}\.\d{2,3}\].*$", RegexOptions.CultureInvariant)]
    private static partial Regex TimedLinePattern();
}
