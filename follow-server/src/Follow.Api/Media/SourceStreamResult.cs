using Follow.Core.Interfaces;

namespace Follow.Api.Media;

public sealed class SourceStreamResult(IMusicImportPreviewSource source) : IResult
{
    public async Task ExecuteAsync(HttpContext httpContext)
    {
        await using var ownedSource = source;
        var range = RangeRequestParser.Parse(
            httpContext.Request.Headers.Range.ToString(),
            source.LengthBytes);
        httpContext.Response.Headers.AcceptRanges = "bytes";
        httpContext.Response.ContentType = source.ContentType;
        if (!string.IsNullOrWhiteSpace(source.ETag))
            httpContext.Response.Headers.ETag = $"\"{source.ETag.Trim('"')}\"";

        if (range.Kind == RangeKind.Unsatisfiable)
        {
            httpContext.Response.StatusCode = StatusCodes.Status416RangeNotSatisfiable;
            httpContext.Response.Headers.ContentRange = $"bytes */{source.LengthBytes}";
            return;
        }

        httpContext.Response.StatusCode = range.Kind == RangeKind.Partial
            ? StatusCodes.Status206PartialContent
            : StatusCodes.Status200OK;
        httpContext.Response.ContentLength = range.Length;
        if (range.Kind == RangeKind.Partial)
        {
            var end = range.Offset + range.Length - 1;
            httpContext.Response.Headers.ContentRange =
                $"bytes {range.Offset}-{end}/{source.LengthBytes}";
        }

        if (HttpMethods.IsHead(httpContext.Request.Method) || range.Length == 0)
            return;

        await source.CopyRangeToAsync(
            range.Offset,
            range.Length,
            httpContext.Response.Body,
            httpContext.RequestAborted);
    }
}
