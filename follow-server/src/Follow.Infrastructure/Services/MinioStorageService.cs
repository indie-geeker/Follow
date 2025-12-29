using Follow.Core.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Minio;
using Minio.DataModel.Args;

namespace Follow.Infrastructure.Services;

/// <summary>
/// MinIO storage service implementation
/// </summary>
public class MinioStorageService : IStorageService
{
    private readonly IMinioClient _minioClient;
    private readonly string _bucketName;
    private readonly ILogger<MinioStorageService> _logger;

    public MinioStorageService(IConfiguration configuration, ILogger<MinioStorageService> logger)
    {
        _logger = logger;
        var minioSettings = configuration.GetSection("MinioSettings");
        
        var endpoint = minioSettings["Endpoint"] ?? "localhost:9000";
        var accessKey = minioSettings["AccessKey"] ?? "minioadmin";
        var secretKey = minioSettings["SecretKey"] ?? "minioadmin";
        var useSSL = bool.Parse(minioSettings["UseSSL"] ?? "false");
        _bucketName = minioSettings["BucketName"] ?? "follow-music";

        _minioClient = new MinioClient()
            .WithEndpoint(endpoint)
            .WithCredentials(accessKey, secretKey)
            .WithSSL(useSSL)
            .Build();

        // Ensure bucket exists
        Task.Run(EnsureBucketExistsAsync).Wait();
    }

    private async Task EnsureBucketExistsAsync()
    {
        try
        {
            var bucketExists = await _minioClient.BucketExistsAsync(
                new BucketExistsArgs().WithBucket(_bucketName));
            
            if (!bucketExists)
            {
                await _minioClient.MakeBucketAsync(
                    new MakeBucketArgs().WithBucket(_bucketName));
                _logger.LogInformation("Created MinIO bucket: {Bucket}", _bucketName);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not ensure bucket exists. MinIO may not be running.");
        }
    }

    public async Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null)
    {
        var objectName = string.IsNullOrEmpty(folder) 
            ? $"{Guid.NewGuid()}/{fileName}" 
            : $"{folder}/{Guid.NewGuid()}/{fileName}";

        await _minioClient.PutObjectAsync(new PutObjectArgs()
            .WithBucket(_bucketName)
            .WithObject(objectName)
            .WithStreamData(fileStream)
            .WithObjectSize(fileStream.Length)
            .WithContentType(contentType));

        _logger.LogInformation("Uploaded file: {ObjectName}", objectName);
        return objectName;
    }

    public async Task<Stream?> GetFileAsync(string filePath)
    {
        try
        {
            var memoryStream = new MemoryStream();
            await _minioClient.GetObjectAsync(new GetObjectArgs()
                .WithBucket(_bucketName)
                .WithObject(filePath)
                .WithCallbackStream(stream => stream.CopyTo(memoryStream)));
            
            memoryStream.Position = 0;
            return memoryStream;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting file: {FilePath}", filePath);
            return null;
        }
    }

    public async Task<bool> DeleteFileAsync(string filePath)
    {
        try
        {
            await _minioClient.RemoveObjectAsync(new RemoveObjectArgs()
                .WithBucket(_bucketName)
                .WithObject(filePath));
            
            _logger.LogInformation("Deleted file: {FilePath}", filePath);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting file: {FilePath}", filePath);
            return false;
        }
    }

    public async Task<string> GetPresignedUrlAsync(string filePath, int expirySeconds = 3600)
    {
        var url = await _minioClient.PresignedGetObjectAsync(new PresignedGetObjectArgs()
            .WithBucket(_bucketName)
            .WithObject(filePath)
            .WithExpiry(expirySeconds));
        
        return url;
    }

    public async Task<bool> FileExistsAsync(string filePath)
    {
        try
        {
            await _minioClient.StatObjectAsync(new StatObjectArgs()
                .WithBucket(_bucketName)
                .WithObject(filePath));
            return true;
        }
        catch
        {
            return false;
        }
    }
}
