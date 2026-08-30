using System.Buffers;
using System.Net;
using System.Net.Http.Headers;
using Follow.Core.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Minio;
using Minio.DataModel.Args;
using Minio.Exceptions;

namespace Follow.Infrastructure.Services;

/// <summary>
/// MinIO storage service implementation
/// </summary>
public class MinioStorageService : IStorageService, IDisposable
{
    private readonly IMinioClient _minioClient;
    private readonly string _bucketName;
    private readonly Uri _endpointUri;
    private readonly ILogger<MinioStorageService> _logger;

    public MinioStorageService(IConfiguration configuration, ILogger<MinioStorageService> logger)
    {
        _logger = logger;
        var minioSettings = configuration.GetSection("MinioSettings");
        
        var endpoint = RequireSetting(minioSettings, "Endpoint");
        var accessKey = RequireSetting(minioSettings, "AccessKey");
        var secretKey = RequireSetting(minioSettings, "SecretKey");
        var useSSL = bool.Parse(minioSettings["UseSSL"] ?? "false");
        _bucketName = minioSettings["BucketName"] ?? "follow-music";
        _endpointUri = new Uri(
            $"{(useSSL ? Uri.UriSchemeHttps : Uri.UriSchemeHttp)}://{endpoint}",
            UriKind.Absolute);

        var httpClient = new HttpClient(new HttpClientHandler
        {
            AllowAutoRedirect = false,
            UseProxy = false
        });
        _minioClient = new MinioClient()
            .WithEndpoint(endpoint)
            .WithCredentials(accessKey, secretKey)
            .WithSSL(useSSL)
            .WithHttpClient(httpClient, disposeHttpClient: true)
            .Build();

        // Ensure bucket exists
        EnsureBucketExistsAsync().GetAwaiter().GetResult();
    }

    private static string RequireSetting(
        IConfigurationSection section,
        string key)
    {
        var value = section[key];
        return string.IsNullOrWhiteSpace(value)
            ? throw new InvalidOperationException(
                $"MinioSettings:{key} 必须通过安全配置提供")
            : value;
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
            _logger.LogCritical(ex, "Could not initialize MinIO bucket {Bucket}", _bucketName);
            throw;
        }
    }

    public async Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null)
    {
        fileName = NormalizeFileName(fileName);
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

    public async Task WriteObjectAsync(
        string objectPath,
        Stream source,
        long length,
        string contentType,
        CancellationToken cancellationToken = default)
    {
        ValidateImportObjectPath(objectPath);
        ArgumentNullException.ThrowIfNull(source);
        ArgumentOutOfRangeException.ThrowIfLessThan(length, 1);
        if (!source.CanRead) throw new ArgumentException("Source stream must be readable.", nameof(source));
        if (string.IsNullOrWhiteSpace(contentType))
            throw new ArgumentException("Content type is required.", nameof(contentType));

        await _minioClient.PutObjectAsync(new PutObjectArgs()
            .WithBucket(_bucketName)
            .WithObject(objectPath)
            .WithStreamData(source)
            .WithObjectSize(length)
            .WithContentType(contentType), cancellationToken);

        _logger.LogInformation("Wrote managed import object: {ObjectName}", objectPath);
    }

    internal static void ValidateImportObjectPath(string objectPath)
    {
        ArgumentNullException.ThrowIfNull(objectPath);
        if (!objectPath.StartsWith("tracks/import/", StringComparison.Ordinal) ||
            objectPath.Length > 1024 ||
            objectPath.StartsWith('/') ||
            objectPath.Contains('\\') ||
            objectPath.Contains("//", StringComparison.Ordinal) ||
            objectPath.Any(char.IsControl) ||
            Uri.TryCreate(objectPath, UriKind.Absolute, out _) ||
            objectPath.Split('/').Any(segment => segment is "" or "." or ".."))
        {
            throw new ArgumentException(
                "Object path must be a relative managed key under tracks/import/.",
                nameof(objectPath));
        }
    }

    public static string NormalizeFileName(string fileName)
    {
        var normalizedSeparators = fileName.Replace('\\', '/');
        var normalized = Path.GetFileName(normalizedSeparators).Trim();
        if (string.IsNullOrWhiteSpace(normalized) || normalized is "." or ".." ||
            normalized.Any(char.IsControl))
        {
            throw new ArgumentException("文件名无效", nameof(fileName));
        }

        return normalized;
    }

    public async Task<StorageObjectMetadata?> GetObjectMetadataAsync(
        string filePath,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var stat = await _minioClient.StatObjectAsync(new StatObjectArgs()
                .WithBucket(_bucketName)
                .WithObject(filePath), cancellationToken);
            return new StorageObjectMetadata(stat.Size, stat.ContentType, stat.ETag);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (ObjectNotFoundException)
        {
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not stat object: {FilePath}", filePath);
            throw;
        }
    }

    public async Task CopyRangeToAsync(
        string filePath,
        long offset,
        long length,
        Stream destination,
        CancellationToken cancellationToken = default)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(offset);
        ArgumentOutOfRangeException.ThrowIfLessThan(length, 1);
        var rangeEnd = checked(offset + length - 1);
        cancellationToken.ThrowIfCancellationRequested();

        // Minio .NET 7.0.0 treats a valid 206 response from GetObjectAsync as
        // PartialContentException. Keep MinIO private and proxy the same signed
        // S3 range request through the SDK-owned internal HttpClient instead.
        var presignedUrl = await _minioClient.PresignedGetObjectAsync(
            new PresignedGetObjectArgs()
            .WithBucket(_bucketName)
            .WithObject(filePath)
            .WithExpiry(60));
        cancellationToken.ThrowIfCancellationRequested();

        if (!Uri.TryCreate(presignedUrl, UriKind.Absolute, out var presignedUri) ||
            !string.Equals(
                presignedUri.Scheme,
                _endpointUri.Scheme,
                StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(
                presignedUri.Host,
                _endpointUri.Host,
                StringComparison.OrdinalIgnoreCase) ||
            presignedUri.Port != _endpointUri.Port ||
            !string.IsNullOrEmpty(presignedUri.UserInfo))
        {
            throw new IOException("MinIO 预签名地址不匹配内部端点");
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, presignedUri);
        request.Headers.Range = new RangeHeaderValue(offset, rangeEnd);
        using var response = await _minioClient.Config.HttpClient.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);

        var contentRange = response.Content.Headers.ContentRange;
        if (response.StatusCode != HttpStatusCode.PartialContent ||
            response.Content.Headers.ContentLength != length ||
            !string.Equals(
                contentRange?.Unit,
                "bytes",
                StringComparison.OrdinalIgnoreCase) ||
            contentRange?.From != offset ||
            contentRange?.To != rangeEnd ||
            contentRange?.Length is not long objectLength ||
            objectLength <= rangeEnd)
        {
            throw new IOException(
                "MinIO 未返回请求的完整字节范围");
        }

        await using var source = await response.Content.ReadAsStreamAsync(
            cancellationToken);
        await CopyExactlyAsync(
            source,
            destination,
            length,
            cancellationToken);
    }

    internal static async Task CopyExactlyAsync(
        Stream source,
        Stream destination,
        long length,
        CancellationToken cancellationToken)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(length);
        var buffer = ArrayPool<byte>.Shared.Rent(64 * 1024);
        try
        {
            var remaining = length;
            while (remaining > 0)
            {
                var bytesRead = await source.ReadAsync(
                    buffer.AsMemory(0, (int)Math.Min(buffer.Length, remaining)),
                    cancellationToken);
                if (bytesRead == 0)
                {
                    throw new EndOfStreamException(
                        "MinIO 字节范围响应提前结束");
                }

                await destination.WriteAsync(
                    buffer.AsMemory(0, bytesRead),
                    cancellationToken);
                remaining -= bytesRead;
            }
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer);
        }
    }

    public void Dispose()
    {
        _minioClient.Dispose();
        GC.SuppressFinalize(this);
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
        catch (ObjectNotFoundException)
        {
            // Outbox deletes are intentionally idempotent.
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting file: {FilePath}", filePath);
            return false;
        }
    }

}
