using Follow.Core.Entities;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

public sealed class MusicImportScanner
{
    private readonly FollowDbContext _context;
    private readonly MusicImportRuntimeSettings _settings;

    public MusicImportScanner(
        FollowDbContext context,
        MusicImportRuntimeSettings settings)
    {
        _context = context;
        _settings = settings;
    }

    public Task ScanAsync(
        Guid batchId,
        CancellationToken cancellationToken = default) =>
        ScanAsync(batchId, leaseOwner: null, cancellationToken);

    public async Task ScanAsync(
        Guid batchId,
        string? leaseOwner,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        cancellationToken.ThrowIfCancellationRequested();

        var batch = await _context.MusicImportBatches
            .SingleOrDefaultAsync(candidate => candidate.Id == batchId, cancellationToken)
            ?? throw new KeyNotFoundException("Music import batch was not found.");
        if (batch.Status != MusicImportBatchStatus.Scanning)
            throw new InvalidOperationException("Only a scanning batch can enumerate source files.");
        ValidateScanLease(batch, leaseOwner);

        var root = MusicImportPathPolicy.Resolve(_settings.SourceRoot, string.Empty);
        var selected = MusicImportPathPolicy.Resolve(
            _settings.SourceRoot,
            batch.RelativeDirectory,
            _settings.MaximumRelativePathLength);
        EnsureSafeDirectoryChain(root.FullPath, selected.RelativePath);

        if (!Directory.Exists(selected.FullPath))
            throw new DirectoryNotFoundException("The configured import directory is unavailable.");

        batch.ScanStartedAt ??= DateTime.UtcNow;
        if (leaseOwner != null)
            batch.LeaseExpiresAt = DateTime.UtcNow + _settings.LeaseDuration;
        await _context.SaveChangesAsync(cancellationToken);

        var ignoredCount = 0;
        var pendingItems = new List<MusicImportItem>(_settings.ScanBatchSize);
        var directories = new Stack<DirectoryInfo>();
        var entriesSinceLeaseCheck = 0;
        var entryLeaseCheckInterval = Math.Min(_settings.ScanBatchSize, 256);
        directories.Push(new DirectoryInfo(selected.FullPath));

        while (directories.TryPop(out var directory))
        {
            cancellationToken.ThrowIfCancellationRequested();

            foreach (var entry in directory.EnumerateFileSystemInfos())
            {
                cancellationToken.ThrowIfCancellationRequested();
                entriesSinceLeaseCheck++;
                if (entriesSinceLeaseCheck >= entryLeaseCheckInterval)
                {
                    if (await StopRequestedAsync(batch, leaseOwner, cancellationToken)) return;
                    entriesSinceLeaseCheck = 0;
                }
                if (MusicImportPathPolicy.IsReparsePoint(entry))
                {
                    ignoredCount++;
                    continue;
                }

                if (entry is DirectoryInfo childDirectory)
                {
                    directories.Push(childDirectory);
                    continue;
                }

                if (entry is not FileInfo file)
                    continue;

                var relativePath = Path.GetRelativePath(root.FullPath, file.FullName)
                    .Replace(Path.DirectorySeparatorChar, '/');
                try
                {
                    AudioFilePolicy.ValidateCandidate(
                        relativePath,
                        file.Length,
                        _settings.MaximumFileBytes,
                        _settings.MaximumRelativePathLength);
                }
                catch (ArgumentException)
                {
                    ignoredCount++;
                    continue;
                }

                pendingItems.Add(new MusicImportItem
                {
                    BatchId = batch.Id,
                    RelativePath = relativePath,
                    OriginalFileName = NormalizeOriginalFileName(file.Name),
                    Extension = file.Extension.ToLowerInvariant(),
                    SizeBytes = file.Length,
                    SourceModifiedAt = NormalizeDatabaseTimestamp(file.LastWriteTimeUtc)
                });

                if (pendingItems.Count >= _settings.ScanBatchSize)
                {
                    if (!await FlushAsync(
                            batch,
                            pendingItems,
                            leaseOwner,
                            cancellationToken))
                        return;
                    if (await StopRequestedAsync(batch, leaseOwner, cancellationToken)) return;
                }
            }

            if (await StopRequestedAsync(batch, leaseOwner, cancellationToken)) return;
        }

        if (!await FlushAsync(batch, pendingItems, leaseOwner, cancellationToken)) return;
        if (await StopRequestedAsync(batch, leaseOwner, cancellationToken)) return;

        batch.DiscoveredFileCount = await _context.MusicImportItems
            .CountAsync(item => item.BatchId == batch.Id, cancellationToken);
        batch.TotalBytes = await _context.MusicImportItems
            .Where(item => item.BatchId == batch.Id)
            .SumAsync(item => item.SizeBytes, cancellationToken);
        batch.IgnoredFileCount = ignoredCount;
        batch.ScanCompletedAt = DateTime.UtcNow;
        MusicImportStateMachine.EnsureTransition(batch.Status, MusicImportBatchStatus.Ready);
        batch.Status = MusicImportBatchStatus.Ready;
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task<bool> FlushAsync(
        MusicImportBatch batch,
        List<MusicImportItem> pendingItems,
        string? leaseOwner,
        CancellationToken cancellationToken)
    {
        if (pendingItems.Count == 0) return true;

        if (!await ConfirmFlushOwnershipAsync(batch, leaseOwner, cancellationToken))
        {
            pendingItems.Clear();
            return false;
        }

        var relativePaths = pendingItems
            .Select(item => item.RelativePath)
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        var existingPaths = await _context.MusicImportItems
            .Where(item => item.BatchId == batch.Id && relativePaths.Contains(item.RelativePath))
            .Select(item => item.RelativePath)
            .ToHashSetAsync(StringComparer.Ordinal, cancellationToken);
        var newItems = pendingItems
            .Where(item => !existingPaths.Contains(item.RelativePath))
            .DistinctBy(item => item.RelativePath, StringComparer.Ordinal)
            .ToArray();

        if (newItems.Length > 0)
        {
            // Fence the item inserts with the batch concurrency token. EF wraps the
            // batch update and chunk inserts in one relational transaction, so a
            // concurrently committed cancel/lease transfer rolls the whole chunk back.
            batch.UpdatedAt = DateTime.UtcNow;
            _context.MusicImportItems.AddRange(newItems);
            try
            {
                await _context.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateConcurrencyException)
            {
                // The relational SaveChanges transaction already rolls inserts back.
                // The InMemory provider is not transactional, so remove only the
                // just-created IDs to preserve the same test/runtime invariant.
                if (!_context.Database.IsRelational())
                {
                    var insertedIds = newItems.Select(item => item.Id).ToArray();
                    _context.ChangeTracker.Clear();
                    var inserted = await _context.MusicImportItems
                        .Where(item => insertedIds.Contains(item.Id))
                        .ToListAsync(cancellationToken);
                    _context.MusicImportItems.RemoveRange(inserted);
                    await _context.SaveChangesAsync(cancellationToken);
                }
                throw;
            }
            foreach (var item in newItems)
                _context.Entry(item).State = EntityState.Detached;
        }

        pendingItems.Clear();
        return true;
    }

    private async Task<bool> ConfirmFlushOwnershipAsync(
        MusicImportBatch batch,
        string? leaseOwner,
        CancellationToken cancellationToken) =>
        !await StopRequestedAsync(batch, leaseOwner, cancellationToken);

    private async Task<bool> StopRequestedAsync(
        MusicImportBatch batch,
        string? leaseOwner,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        await _context.Entry(batch).ReloadAsync(cancellationToken);
        if (batch.Status == MusicImportBatchStatus.CancelRequested)
        {
            await ReleaseCancelledScanLeaseAsync(batch, leaseOwner, cancellationToken);
            return true;
        }
        if (batch.Status != MusicImportBatchStatus.Scanning)
            throw new InvalidOperationException("The batch left the scanning state unexpectedly.");
        ValidateScanLease(batch, leaseOwner);
        if (leaseOwner != null)
        {
            batch.LeaseExpiresAt = DateTime.UtcNow + _settings.LeaseDuration;
            await _context.SaveChangesAsync(cancellationToken);
        }
        return false;
    }

    private async Task ReleaseCancelledScanLeaseAsync(
        MusicImportBatch batch,
        string? leaseOwner,
        CancellationToken cancellationToken)
    {
        if (leaseOwner == null ||
            !string.Equals(batch.LeaseOwner, leaseOwner, StringComparison.Ordinal))
            return;

        if (_context.Database.IsRelational())
        {
            await _context.MusicImportBatches
                .Where(candidate => candidate.Id == batch.Id &&
                    candidate.Status == MusicImportBatchStatus.CancelRequested &&
                    candidate.LeaseOwner == leaseOwner)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(candidate => candidate.LeaseOwner, (string?)null)
                    .SetProperty(candidate => candidate.LeaseExpiresAt, (DateTime?)null)
                    .SetProperty(candidate => candidate.UpdatedAt, DateTime.UtcNow)
                    .SetProperty(candidate => candidate.Version, candidate => candidate.Version + 1),
                    cancellationToken);
            await _context.Entry(batch).ReloadAsync(cancellationToken);
            return;
        }

        batch.LeaseOwner = null;
        batch.LeaseExpiresAt = null;
        try
        {
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            await _context.Entry(batch).ReloadAsync(cancellationToken);
            if (batch.Status != MusicImportBatchStatus.CancelRequested &&
                batch.Status != MusicImportBatchStatus.Cancelled)
                throw;
        }
    }

    private static void ValidateScanLease(
        MusicImportBatch batch,
        string? leaseOwner)
    {
        if (leaseOwner == null)
        {
            if (batch.LeaseOwner != null)
                throw new InvalidOperationException("An owned scan requires its matching worker lease.");
            return;
        }

        if (!string.Equals(batch.LeaseOwner, leaseOwner, StringComparison.Ordinal) ||
            batch.LeaseExpiresAt is not DateTime leaseExpiresAt ||
            leaseExpiresAt <= DateTime.UtcNow)
        {
            throw new InvalidOperationException("The music import scan lease is no longer owned by this worker.");
        }
    }

    private void EnsureEnabled()
    {
        if (!_settings.Enabled)
            throw new InvalidOperationException("Music library import is disabled.");
        if (_settings.ScanBatchSize < 1)
            throw new InvalidOperationException("Music import scan batch size must be positive.");
    }

    private static void EnsureSafeDirectoryChain(string root, string relativeDirectory)
    {
        var current = new DirectoryInfo(root);
        if (!current.Exists)
            throw new DirectoryNotFoundException("The configured import source is unavailable.");
        if (MusicImportPathPolicy.IsReparsePoint(current))
            throw new InvalidOperationException("The configured import source cannot be a reparse point.");

        foreach (var segment in relativeDirectory.Split('/', StringSplitOptions.RemoveEmptyEntries))
        {
            current = new DirectoryInfo(Path.Combine(current.FullName, segment));
            if (!current.Exists)
                throw new DirectoryNotFoundException("The selected import directory is unavailable.");
            if (MusicImportPathPolicy.IsReparsePoint(current))
                throw new InvalidOperationException("Import directory reparse points are not allowed.");
        }
    }

    internal static DateTime NormalizeDatabaseTimestamp(DateTime timestampUtc)
    {
        var utc = timestampUtc.Kind == DateTimeKind.Utc
            ? timestampUtc
            : timestampUtc.ToUniversalTime();
        return new DateTime(utc.Ticks - utc.Ticks % 10, DateTimeKind.Utc);
    }

    internal static string NormalizeOriginalFileName(string fileName)
    {
        const int maximumLength = 512;
        if (fileName.Length <= maximumLength) return fileName;

        var extension = Path.GetExtension(fileName);
        if (extension.Length >= maximumLength) return fileName[..maximumLength];
        return fileName[..(maximumLength - extension.Length)] + extension;
    }
}
