namespace Follow.Api.Media;

public enum RangeKind
{
    Full,
    Partial,
    Unsatisfiable
}

public readonly record struct ParsedRange(RangeKind Kind, long Offset, long Length);

public static class RangeRequestParser
{
    public static ParsedRange Parse(string? header, long objectLength)
    {
        if (objectLength < 0)
            throw new ArgumentOutOfRangeException(nameof(objectLength));

        if (string.IsNullOrWhiteSpace(header))
            return new ParsedRange(RangeKind.Full, 0, objectLength);

        if (objectLength == 0 || !header.StartsWith("bytes=", StringComparison.OrdinalIgnoreCase))
            return Unsatisfiable();

        var value = header[6..].Trim();
        if (value.Contains(',')) return Unsatisfiable();

        var separator = value.IndexOf('-');
        if (separator < 0 || value.IndexOf('-', separator + 1) >= 0)
            return Unsatisfiable();

        var startText = value[..separator].Trim();
        var endText = value[(separator + 1)..].Trim();

        if (startText.Length == 0)
        {
            if (!long.TryParse(endText, out var suffixLength) || suffixLength <= 0)
                return Unsatisfiable();
            var length = Math.Min(suffixLength, objectLength);
            return new ParsedRange(RangeKind.Partial, objectLength - length, length);
        }

        if (!long.TryParse(startText, out var start) || start < 0 || start >= objectLength)
            return Unsatisfiable();

        if (endText.Length == 0)
            return new ParsedRange(RangeKind.Partial, start, objectLength - start);

        if (!long.TryParse(endText, out var end) || end < start)
            return Unsatisfiable();

        end = Math.Min(end, objectLength - 1);
        return new ParsedRange(RangeKind.Partial, start, end - start + 1);
    }

    private static ParsedRange Unsatisfiable() =>
        new(RangeKind.Unsatisfiable, 0, 0);
}
