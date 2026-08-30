using Follow.Api.Media;

namespace Follow.Api.Tests;

public class RangeRequestParserTests
{
    [Theory]
    [InlineData(null, 1000, RangeKind.Full, 0, 1000)]
    [InlineData("bytes=0-99", 1000, RangeKind.Partial, 0, 100)]
    [InlineData("bytes=100-", 1000, RangeKind.Partial, 100, 900)]
    [InlineData("bytes=-100", 1000, RangeKind.Partial, 900, 100)]
    [InlineData("bytes=999-999", 1000, RangeKind.Partial, 999, 1)]
    [InlineData("bytes=900-1200", 1000, RangeKind.Partial, 900, 100)]
    [InlineData("bytes=1000-", 1000, RangeKind.Unsatisfiable, 0, 0)]
    [InlineData("bytes=0-1,3-4", 1000, RangeKind.Unsatisfiable, 0, 0)]
    [InlineData("items=0-1", 1000, RangeKind.Unsatisfiable, 0, 0)]
    public void Parse_ReturnsExpectedSingleRange(
        string? header,
        long objectLength,
        RangeKind expectedKind,
        long expectedOffset,
        long expectedLength)
    {
        var result = RangeRequestParser.Parse(header, objectLength);

        Assert.Equal(expectedKind, result.Kind);
        Assert.Equal(expectedOffset, result.Offset);
        Assert.Equal(expectedLength, result.Length);
    }
}
