using System.Collections.Concurrent;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Minio;
using Minio.DataModel.Args;
using Npgsql;

namespace Follow.Api.Tests.Infrastructure;

internal sealed class DisposableMusicImportStack : IAsyncDisposable
{
    private readonly string _adminConnectionString;
    private readonly string _databaseName;
    private readonly string _bucketName;
    private readonly string _minioEndpoint;
    private readonly string _minioAccessKey;
    private readonly string _minioSecretKey;
    private bool _sourceDirectorySealed;

    private DisposableMusicImportStack(
        string adminConnectionString,
        string connectionString,
        string databaseName,
        string bucketName,
        string minioEndpoint,
        string minioAccessKey,
        string minioSecretKey,
        string sourceDirectory,
        TrackingStorage storage)
    {
        _adminConnectionString = adminConnectionString;
        ConnectionString = connectionString;
        _databaseName = databaseName;
        _bucketName = bucketName;
        _minioEndpoint = minioEndpoint;
        _minioAccessKey = minioAccessKey;
        _minioSecretKey = minioSecretKey;
        SourceDirectory = sourceDirectory;
        Storage = storage;
    }

    public string ConnectionString { get; }
    public string SourceDirectory { get; }
    public TrackingStorage Storage { get; }

    public static async Task<DisposableMusicImportStack> CreateAsync()
    {
        var adminConnectionString = RequireEnvironment("FOLLOW_TEST_POSTGRES");
        var minioEndpoint = RequireLoopbackEndpoint(
            RequireEnvironment("FOLLOW_TEST_MINIO_ENDPOINT"));
        var minioAccessKey = RequireEnvironment("FOLLOW_TEST_MINIO_ACCESS_KEY");
        var minioSecretKey = RequireEnvironment("FOLLOW_TEST_MINIO_SECRET_KEY");
        var databaseName = $"follow_import_e2e_{Guid.NewGuid():N}";
        var bucketName = $"follow-test-{Guid.NewGuid():N}";
        var sourceDirectory = Path.Combine(
            Path.GetTempPath(),
            $"follow-import-source-{Guid.NewGuid():N}");
        Directory.CreateDirectory(sourceDirectory);

        var adminBuilder = new NpgsqlConnectionStringBuilder(adminConnectionString);
        if (!IsLoopback(adminBuilder.Host ?? string.Empty))
            throw new InvalidOperationException("Disposable PostgreSQL must use a loopback host.");
        var databaseBuilder = new NpgsqlConnectionStringBuilder(adminConnectionString)
        {
            Database = databaseName,
            Pooling = false
        };
        await using (var admin = new NpgsqlConnection(adminBuilder.ConnectionString))
        {
            await admin.OpenAsync();
            await using var create = new NpgsqlCommand(
                $"CREATE DATABASE \"{databaseName}\"",
                admin);
            await create.ExecuteNonQueryAsync();
        }

        try
        {
            var configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["MinioSettings:Endpoint"] = minioEndpoint,
                    ["MinioSettings:AccessKey"] = minioAccessKey,
                    ["MinioSettings:SecretKey"] = minioSecretKey,
                    ["MinioSettings:BucketName"] = bucketName,
                    ["MinioSettings:UseSSL"] = "false"
                })
                .Build();
            var innerStorage = new MinioStorageService(
                configuration,
                NullLogger<MinioStorageService>.Instance);
            var stack = new DisposableMusicImportStack(
                adminConnectionString,
                databaseBuilder.ConnectionString,
                databaseName,
                bucketName,
                minioEndpoint,
                minioAccessKey,
                minioSecretKey,
                sourceDirectory,
                new TrackingStorage(innerStorage));
            await using var context = stack.CreateContext();
            await context.Database.MigrateAsync();
            return stack;
        }
        catch
        {
            await DropDatabaseAsync(adminConnectionString, databaseName);
            Directory.Delete(sourceDirectory, recursive: true);
            throw;
        }
    }

    public FollowDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseNpgsql(ConnectionString)
            .Options);

    public void SealSourceDirectoryReadOnly()
    {
        if (OperatingSystem.IsWindows()) return;
        File.SetUnixFileMode(
            SourceDirectory,
            UnixFileMode.UserRead | UnixFileMode.UserExecute |
            UnixFileMode.GroupRead | UnixFileMode.GroupExecute |
            UnixFileMode.OtherRead | UnixFileMode.OtherExecute);
        _sourceDirectorySealed = true;
    }

    public async ValueTask DisposeAsync()
    {
        if (_sourceDirectorySealed && Directory.Exists(SourceDirectory) && !OperatingSystem.IsWindows())
        {
            File.SetUnixFileMode(
                SourceDirectory,
                UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        }

        Storage.Dispose();
        using (var minio = new MinioClient()
            .WithEndpoint(_minioEndpoint)
            .WithCredentials(_minioAccessKey, _minioSecretKey)
            .Build())
        {
            foreach (var objectPath in Storage.WrittenObjectPaths.Distinct(StringComparer.Ordinal))
            {
                await minio.RemoveObjectAsync(new RemoveObjectArgs()
                    .WithBucket(_bucketName)
                    .WithObject(objectPath));
            }
            await minio.RemoveBucketAsync(new RemoveBucketArgs().WithBucket(_bucketName));
        }

        await DropDatabaseAsync(_adminConnectionString, _databaseName);
        if (Directory.Exists(SourceDirectory))
            Directory.Delete(SourceDirectory, recursive: true);
    }

    private static async Task DropDatabaseAsync(string adminConnectionString, string databaseName)
    {
        await using var admin = new NpgsqlConnection(adminConnectionString);
        await admin.OpenAsync();
        await using var drop = new NpgsqlCommand(
            $"DROP DATABASE IF EXISTS \"{databaseName}\" WITH (FORCE)",
            admin);
        await drop.ExecuteNonQueryAsync();
    }

    private static string RequireEnvironment(string name) =>
        Environment.GetEnvironmentVariable(name) is { Length: > 0 } value
            ? value
            : throw new InvalidOperationException($"{name} is required for isolated integration tests.");

    private static string RequireLoopbackEndpoint(string endpoint)
    {
        if (!Uri.TryCreate($"http://{endpoint}", UriKind.Absolute, out var uri) ||
            !IsLoopback(uri.Host))
        {
            throw new InvalidOperationException("Disposable MinIO must use a loopback endpoint.");
        }
        return endpoint;
    }

    private static bool IsLoopback(string host) =>
        string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(host, "127.0.0.1", StringComparison.Ordinal) ||
        string.Equals(host, "::1", StringComparison.Ordinal);

    internal sealed class TrackingStorage(MinioStorageService inner) : IStorageService, IDisposable
    {
        public ConcurrentQueue<string> WrittenObjectPaths { get; } = new();

        public async Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default)
        {
            WrittenObjectPaths.Enqueue(objectPath);
            await inner.WriteObjectAsync(objectPath, source, length, contentType, cancellationToken);
        }

        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) =>
            inner.GetObjectMetadataAsync(filePath, cancellationToken);

        public Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) =>
            inner.CopyRangeToAsync(filePath, offset, length, destination, cancellationToken);

        public Task<bool> DeleteFileAsync(string filePath) => inner.DeleteFileAsync(filePath);

        public Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null) =>
            inner.UploadFileAsync(fileStream, fileName, contentType, folder);

        public void Dispose() => inner.Dispose();
    }
}
