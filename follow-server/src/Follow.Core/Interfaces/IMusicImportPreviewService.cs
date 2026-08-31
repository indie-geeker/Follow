namespace Follow.Core.Interfaces;

public interface IMusicImportPreviewService
{
    Task<IMusicImportPreviewSource?> OpenAsync(
        Guid itemId,
        CancellationToken cancellationToken = default);
}

public interface IMusicImportPreviewSource : IAsyncDisposable
{
    long LengthBytes { get; }
    string ContentType { get; }
    string? ETag { get; }

    Task CopyRangeToAsync(
        long offset,
        long length,
        Stream destination,
        CancellationToken cancellationToken = default);
}
