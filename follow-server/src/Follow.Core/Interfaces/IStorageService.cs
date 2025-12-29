namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for file storage (MinIO)
/// </summary>
public interface IStorageService
{
    /// <summary>
    /// Upload a file to storage
    /// </summary>
    Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null);

    /// <summary>
    /// Get a file stream from storage
    /// </summary>
    Task<Stream?> GetFileAsync(string filePath);

    /// <summary>
    /// Delete a file from storage
    /// </summary>
    Task<bool> DeleteFileAsync(string filePath);

    /// <summary>
    /// Get a presigned URL for direct access
    /// </summary>
    Task<string> GetPresignedUrlAsync(string filePath, int expirySeconds = 3600);

    /// <summary>
    /// Check if a file exists
    /// </summary>
    Task<bool> FileExistsAsync(string filePath);
}
