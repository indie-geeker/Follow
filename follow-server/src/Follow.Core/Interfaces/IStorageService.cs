namespace Follow.Core.Interfaces;

public interface IStorageService
{
    Task WriteObjectAsync(
        string objectPath,
        Stream source,
        long length,
        string contentType,
        CancellationToken cancellationToken = default);

    Task<string> UploadFileAsync(
        Stream fileStream,
        string fileName,
        string contentType,
        string? folder = null);

    Task<StorageObjectMetadata?> GetObjectMetadataAsync(
        string filePath,
        CancellationToken cancellationToken = default);

    Task CopyRangeToAsync(
        string filePath,
        long offset,
        long length,
        Stream destination,
        CancellationToken cancellationToken = default);

    Task<bool> DeleteFileAsync(string filePath);
}

public sealed record StorageObjectMetadata(
    long Length,
    string? ContentType,
    string? ETag);
