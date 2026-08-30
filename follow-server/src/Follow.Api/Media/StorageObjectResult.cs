using Follow.Core.Interfaces;

namespace Follow.Api.Media;

public sealed class StorageObjectResult : IResult
{
    private readonly IStorageService _storageService;
    private readonly string _path;
    private readonly string _fallbackContentType;

    public StorageObjectResult(
        IStorageService storageService,
        string path,
        string fallbackContentType)
    {
        _storageService = storageService;
        _path = path;
        _fallbackContentType = fallbackContentType;
    }

    public async Task ExecuteAsync(HttpContext httpContext)
    {
        var cancellationToken = httpContext.RequestAborted;
        var metadata = await _storageService.GetObjectMetadataAsync(_path, cancellationToken);
        if (metadata == null)
        {
            httpContext.Response.StatusCode = StatusCodes.Status404NotFound;
            return;
        }

        var range = RangeRequestParser.Parse(
            httpContext.Request.Headers.Range.ToString(),
            metadata.Length);
        httpContext.Response.Headers.AcceptRanges = "bytes";
        // Object metadata is not an HTTP trust boundary. Every caller supplies a
        // route-controlled media type so an uploaded object cannot become active HTML.
        httpContext.Response.ContentType = _fallbackContentType;
        if (!string.IsNullOrWhiteSpace(metadata.ETag))
            httpContext.Response.Headers.ETag = $"\"{metadata.ETag.Trim('"')}\"";

        if (range.Kind == RangeKind.Unsatisfiable)
        {
            httpContext.Response.StatusCode = StatusCodes.Status416RangeNotSatisfiable;
            httpContext.Response.Headers.ContentRange = $"bytes */{metadata.Length}";
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
                $"bytes {range.Offset}-{end}/{metadata.Length}";
        }

        if (HttpMethods.IsHead(httpContext.Request.Method) || range.Length == 0)
            return;

        await _storageService.CopyRangeToAsync(
            _path,
            range.Offset,
            range.Length,
            httpContext.Response.Body,
            cancellationToken);
    }
}
