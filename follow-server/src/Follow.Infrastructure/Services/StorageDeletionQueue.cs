using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Microsoft.Extensions.Logging;

namespace Follow.Infrastructure.Services;

public sealed class StorageDeletionQueue
{
    private static readonly string[] ManagedPrefixes =
        ["tracks/", "covers/", "lyrics/", "artists/", "albums/"];

    private readonly FollowDbContext _context;
    private readonly ILogger<StorageDeletionQueue>? _logger;

    public StorageDeletionQueue(
        FollowDbContext context,
        ILogger<StorageDeletionQueue>? logger = null)
    {
        _context = context;
        _logger = logger;
    }

    public void Enqueue(string objectPath)
    {
        if (!IsManagedObjectPath(objectPath))
            throw new ArgumentException("对象路径不属于受管媒体目录", nameof(objectPath));

        _context.StorageDeletionJobs.Add(new StorageDeletionJob
        {
            ObjectPath = objectPath,
            NextAttemptAt = DateTime.UtcNow
        });
    }

    public bool TryEnqueue(string? objectPath)
    {
        if (!IsManagedObjectPath(objectPath)) return false;
        Enqueue(objectPath!);
        return true;
    }

    public async Task<bool> CompensateUploadAsync(
        IStorageService storageService,
        string objectPath)
    {
        if (!IsManagedObjectPath(objectPath))
        {
            _logger?.LogCritical(
                "Cannot compensate unmanaged storage object {ObjectPath}",
                objectPath);
            return false;
        }

        try
        {
            if (await storageService.DeleteFileAsync(objectPath))
                return true;

            _logger?.LogWarning(
                "Immediate compensation failed for storage object {ObjectPath}; queuing retry",
                objectPath);
        }
        catch (Exception ex)
        {
            _logger?.LogWarning(
                ex,
                "Immediate compensation threw for storage object {ObjectPath}; queuing retry",
                objectPath);
        }

        try
        {
            // A failed business SaveChanges can leave pending mutations in the
            // tracker. Only the durable cleanup job may be persisted here.
            _context.ChangeTracker.Clear();
            Enqueue(objectPath);
            await _context.SaveChangesAsync();
            return true;
        }
        catch (Exception ex)
        {
            _logger?.LogCritical(
                ex,
                "Failed to persist storage compensation job for {ObjectPath}",
                objectPath);
            return false;
        }
    }

    public static bool IsManagedObjectPath(string? objectPath)
    {
        if (string.IsNullOrWhiteSpace(objectPath) ||
            objectPath.StartsWith('/') ||
            objectPath.Contains("..", StringComparison.Ordinal) ||
            objectPath.Contains('\\') ||
            Uri.TryCreate(objectPath, UriKind.Absolute, out _))
        {
            return false;
        }

        return ManagedPrefixes.Any(prefix =>
            objectPath.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
    }
}
