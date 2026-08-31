using System.Buffers;
using System.Security.Cryptography;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace Follow.Infrastructure.Services;

public sealed class MusicImportProcessor
{
    internal const string TrackHashUniqueConstraintName = "UX_Tracks_ContentSha256";

    private readonly FollowDbContext _context;
    private readonly IStorageService _storage;
    private readonly IAudioMetadataExtractor _metadataExtractor;
    private readonly EmbeddedTrackAssetWriter _assetWriter;
    private readonly MusicImportRuntimeSettings _settings;
    private readonly ILogger<MusicImportProcessor> _logger;
    private readonly IServiceScopeFactory? _scopeFactory;

    public MusicImportProcessor(
        FollowDbContext context,
        IStorageService storage,
        IAudioMetadataExtractor metadataExtractor,
        EmbeddedTrackAssetWriter assetWriter,
        MusicImportRuntimeSettings settings,
        ILogger<MusicImportProcessor> logger,
        IServiceScopeFactory? scopeFactory = null)
    {
        _context = context;
        _storage = storage;
        _metadataExtractor = metadataExtractor;
        _assetWriter = assetWriter;
        _settings = settings;
        _logger = logger;
        _scopeFactory = scopeFactory;
    }

    public async Task ProcessAsync(
        Guid itemId,
        string leaseOwner,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabled();
        var item = await _context.MusicImportItems
            .SingleOrDefaultAsync(candidate => candidate.Id == itemId, cancellationToken)
            ?? throw new KeyNotFoundException("Music import item was not found.");
        ValidateClaim(item, leaseOwner);

        if (_scopeFactory == null)
        {
            await ProcessClaimedItemAsync(item, leaseOwner, cancellationToken, null);
            return;
        }

        using var processCancellation = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken);
        using var heartbeatStop = new CancellationTokenSource();
        var heartbeatState = new LeaseHeartbeatState();
        var heartbeatTask = RunLeaseHeartbeatAsync(
            item.Id,
            leaseOwner,
            processCancellation,
            heartbeatStop.Token,
            heartbeatState);
        var heartbeatStopped = 0;
        async Task StopHeartbeatAsync()
        {
            if (Interlocked.Exchange(ref heartbeatStopped, 1) == 0)
                heartbeatStop.Cancel();
            await heartbeatTask;
        }
        try
        {
            await ProcessClaimedItemAsync(
                item,
                leaseOwner,
                processCancellation.Token,
                StopHeartbeatAsync);
            if (heartbeatState.Failure != null)
                throw new InvalidOperationException(
                    "The music import item lease heartbeat could not be maintained.",
                    heartbeatState.Failure);
        }
        catch (OperationCanceledException exception)
            when (!cancellationToken.IsCancellationRequested &&
                  heartbeatState.Failure != null)
        {
            throw new InvalidOperationException(
                "The music import item lease heartbeat could not be maintained.",
                heartbeatState.Failure ?? exception);
        }
        finally
        {
            try
            {
                await StopHeartbeatAsync();
            }
            catch (OperationCanceledException) when (heartbeatStop.IsCancellationRequested)
            {
                // Normal heartbeat shutdown after this processor relinquishes the item.
            }
        }
    }

    private async Task ProcessClaimedItemAsync(
        MusicImportItem item,
        string leaseOwner,
        CancellationToken cancellationToken,
        Func<Task>? stopHeartbeat)
    {
        string? objectPath = null;
        try
        {
            if (!await PrepareRecoveredObjectAsync(
                    item,
                    leaseOwner,
                    cancellationToken,
                    stopHeartbeat))
                return;

            var resolved = MusicImportPathPolicy.Resolve(
                _settings.SourceRoot,
                item.RelativePath,
                _settings.MaximumRelativePathLength);
            var sourceFile = ValidateSafeSourceFile(resolved, item);

            item.Stage = MusicImportItemStage.Hashing;
            await RenewLeaseAsync(item, leaseOwner, cancellationToken);

            await using var source = new FileStream(
                sourceFile.FullName,
                new FileStreamOptions
                {
                    Mode = FileMode.Open,
                    Access = FileAccess.Read,
                    Share = FileShare.Read,
                    Options = FileOptions.Asynchronous | FileOptions.SequentialScan
                });
            EnsureSourceSnapshot(sourceFile, source, item);
            var contentHash = await HashSourceAsync(
                source,
                item,
                leaseOwner,
                cancellationToken);
            item.ContentSha256 = contentHash;
            EnsureSourceSnapshot(sourceFile, source, item);

            var existingTrack = await _context.Tracks
                .SingleOrDefaultAsync(
                    track => track.ContentSha256 != null &&
                        track.ContentSha256.SequenceEqual(contentHash),
                    cancellationToken);
            if (existingTrack != null)
            {
                await CompleteDuplicateAsync(
                    item,
                    existingTrack.Id,
                    leaseOwner,
                    cancellationToken,
                    stopHeartbeat);
                return;
            }

            item.Stage = MusicImportItemStage.Parsing;
            await RenewLeaseAsync(item, leaseOwner, cancellationToken);
            AudioMetadata metadata;
            try
            {
                metadata = await _metadataExtractor.ExtractAsync(
                    source,
                    item.OriginalFileName,
                    cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                throw new ProcessingFailureException(
                    "INVALID_METADATA",
                    retryable: false,
                    "Audio metadata could not be parsed.",
                    exception);
            }

            ValidateMetadata(metadata);
            EnsureSourceSnapshot(sourceFile, source, item);
            if (!AudioFilePolicy.TryGetCanonicalContentType(item.RelativePath, out var contentType))
                throw new ProcessingFailureException(
                    "UNSUPPORTED_FORMAT",
                    retryable: false,
                    "The source file extension is not supported.");

            objectPath = BuildObjectPath(item);
            MinioStorageService.ValidateImportObjectPath(objectPath);
            item.Stage = MusicImportItemStage.Uploading;
            item.ObjectPath = objectPath;
            await RenewLeaseAsync(item, leaseOwner, cancellationToken);
            source.Position = 0;
            using var verifiedUpload = new VerifyingReadStream(
                source,
                _settings.LeaseDuration,
                token => RenewLeaseAsync(item, leaseOwner, token));
            try
            {
                await _storage.WriteObjectAsync(
                    objectPath,
                    verifiedUpload,
                    item.SizeBytes,
                    contentType,
                    cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                await TryDeleteImportObjectAsync(objectPath, item.Id, leaseOwner);
                throw;
            }
            catch (Exception exception)
            {
                throw new ProcessingFailureException(
                    "STORAGE_ERROR",
                    retryable: true,
                    "The managed object write failed.",
                    exception);
            }

            if (verifiedUpload.BytesRead != item.SizeBytes ||
                !CryptographicOperations.FixedTimeEquals(
                    verifiedUpload.GetHash(),
                    contentHash))
            {
                throw new ProcessingFailureException(
                    "SOURCE_CHANGED",
                    retryable: false,
                    "The bytes uploaded no longer match the scanned source.");
            }
            EnsureSourceSnapshot(sourceFile, source, item);

            item.Stage = MusicImportItemStage.Persisting;
            item.ObjectPath = objectPath;
            await RenewLeaseAsync(item, leaseOwner, cancellationToken);
            await PersistTrackAsync(
                item,
                metadata,
                contentHash,
                objectPath,
                leaseOwner,
                cancellationToken,
                stopHeartbeat);
        }
        catch (ProcessingFailureException failure)
        {
            var preserveObjectPath = objectPath != null &&
                !await TryDeleteImportObjectAsync(objectPath, item.Id, leaseOwner)
                ? objectPath
                : null;
            await MarkFailedAsync(
                item.Id,
                leaseOwner,
                failure.Code,
                failure.Retryable,
                failure.Message,
                preserveObjectPath,
                cancellationToken,
                stopHeartbeat);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            var preserveObjectPath = objectPath != null &&
                !await TryDeleteImportObjectAsync(objectPath, item.Id, leaseOwner)
                ? objectPath
                : null;
            _logger.LogError(
                "Unexpected import failure for item {ItemId}: {ExceptionType}",
                item.Id,
                exception.GetType().Name);
            await MarkFailedAsync(
                item.Id,
                leaseOwner,
                "PROCESSING_ERROR",
                retryable: true,
                "Unexpected processing failure.",
                preserveObjectPath,
                cancellationToken,
                stopHeartbeat);
        }
    }

    private async Task<bool> PrepareRecoveredObjectAsync(
        MusicImportItem item,
        string leaseOwner,
        CancellationToken cancellationToken,
        Func<Task>? stopHeartbeat)
    {
        if (item.ObjectPath == null) return true;

        var expectedPath = BuildObjectPath(item);
        if (!string.Equals(item.ObjectPath, expectedPath, StringComparison.Ordinal) ||
            !IsValidManagedImportPath(item.ObjectPath))
        {
            await DeferRecoveredObjectCleanupAsync(
                item,
                leaseOwner,
                "CLEANUP_UNSAFE",
                "The managed object path could not be verified for safe cleanup.",
                cancellationToken,
                stopHeartbeat);
            return false;
        }

        var referencedTrack = await _context.Tracks
            .OrderBy(track => track.CreatedAt)
            .FirstOrDefaultAsync(
                track => track.FilePath == item.ObjectPath,
                cancellationToken);
        if (referencedTrack != null)
        {
            await RenewLeaseAsync(item, leaseOwner, cancellationToken);
            if (stopHeartbeat != null) await stopHeartbeat();
            CompleteItem(
                item,
                MusicImportItemStatus.Imported,
                referencedTrack.Id,
                item.ObjectPath);
            await _context.SaveChangesAsync(cancellationToken);
            return false;
        }

        if (!await TryDeleteImportObjectAsync(item.ObjectPath, item.Id, leaseOwner))
        {
            await DeferRecoveredObjectCleanupAsync(
                item,
                leaseOwner,
                "CLEANUP_PENDING",
                "The managed object could not be deleted and cleanup will be retried.",
                cancellationToken,
                stopHeartbeat);
            return false;
        }

        item.ObjectPath = null;
        item.Stage = MusicImportItemStage.None;
        await RenewLeaseAsync(item, leaseOwner, cancellationToken);
        return true;
    }

    private async Task DeferRecoveredObjectCleanupAsync(
        MusicImportItem item,
        string leaseOwner,
        string errorCode,
        string errorMessage,
        CancellationToken cancellationToken,
        Func<Task>? stopHeartbeat)
    {
        await RenewLeaseAsync(item, leaseOwner, cancellationToken);
        if (stopHeartbeat != null) await stopHeartbeat();
        item.Status = MusicImportItemStatus.Pending;
        item.Stage = MusicImportItemStage.None;
        item.Retryable = true;
        item.NextAttemptAt = DateTime.UtcNow.AddMinutes(1);
        item.LeaseOwner = null;
        item.LeaseExpiresAt = null;
        item.ErrorCode = errorCode;
        item.ErrorMessage = errorMessage;
        item.StartedAt = null;
        item.CompletedAt = null;
        await _context.SaveChangesAsync(cancellationToken);
    }

    private static string BuildObjectPath(MusicImportItem item) =>
        $"tracks/import/{item.Id}/audio{item.Extension.ToLowerInvariant()}";

    private static bool IsValidManagedImportPath(string objectPath)
    {
        try
        {
            MinioStorageService.ValidateImportObjectPath(objectPath);
            return true;
        }
        catch (ArgumentException)
        {
            return false;
        }
    }

    private async Task RunLeaseHeartbeatAsync(
        Guid itemId,
        string leaseOwner,
        CancellationTokenSource processCancellation,
        CancellationToken heartbeatStop,
        LeaseHeartbeatState state)
    {
        try
        {
            while (!heartbeatStop.IsCancellationRequested)
            {
                await using var scope = _scopeFactory!.CreateAsyncScope();
                var heartbeatContext = scope.ServiceProvider
                    .GetRequiredService<FollowDbContext>();
                var now = DateTime.UtcNow;
                var renewed = await heartbeatContext.TryRenewMusicImportItemLeaseAsync(
                    itemId,
                    leaseOwner,
                    now,
                    now + _settings.LeaseDuration,
                    heartbeatStop);
                if (!renewed)
                {
                    state.Failure = new InvalidOperationException(
                        "The music import item lease is no longer owned by this processor.");
                    processCancellation.Cancel();
                    return;
                }

                await Task.Delay(HeartbeatInterval(), heartbeatStop);
            }
        }
        catch (OperationCanceledException) when (heartbeatStop.IsCancellationRequested)
        {
            // Normal stop requested by the owning processor.
        }
        catch (Exception exception)
        {
            state.Failure = exception;
            processCancellation.Cancel();
        }
    }

    private TimeSpan HeartbeatInterval()
    {
        var interval = TimeSpan.FromTicks(_settings.LeaseDuration.Ticks / 3);
        var minimum = TimeSpan.FromMilliseconds(50);
        var maximum = TimeSpan.FromSeconds(30);
        if (interval < minimum) return minimum;
        return interval > maximum ? maximum : interval;
    }

    private async Task PersistTrackAsync(
        MusicImportItem item,
        AudioMetadata metadata,
        byte[] contentHash,
        string objectPath,
        string leaseOwner,
        CancellationToken cancellationToken,
        Func<Task>? stopHeartbeat)
    {
        await RenewLeaseAsync(item, leaseOwner, cancellationToken);
        if (stopHeartbeat != null) await stopHeartbeat();

        var trackId = Guid.NewGuid();
        EmbeddedTrackAssetResult embeddedAssets;
        try
        {
            embeddedAssets = await _assetWriter.WriteAsync(
                trackId,
                metadata.CoverData,
                metadata.CoverContentType,
                metadata.TimedLyrics,
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            throw new ProcessingFailureException(
                "STORAGE_ERROR",
                retryable: true,
                "Embedded track asset storage failed.",
                exception);
        }

        await using var transaction = _context.Database.IsRelational()
            ? await _context.Database.BeginTransactionAsync(cancellationToken)
            : null;
        try
        {
            ValidateClaim(item, leaseOwner);
            var artist = await GetOrCreateArtistAsync(metadata.Artist, cancellationToken);
            var album = await GetOrCreateAlbumAsync(metadata.Album, artist, cancellationToken);
            var track = new Track
            {
                Id = trackId,
                Title = metadata.Title.Trim(),
                DurationSeconds = metadata.DurationSeconds,
                FilePath = objectPath,
                BitRate = metadata.BitRate,
                Format = metadata.Format.Trim().ToLowerInvariant(),
                ContentSha256 = contentHash,
                FileSizeBytes = item.SizeBytes,
                OriginalFileName = item.OriginalFileName,
                CoverUrl = embeddedAssets.CoverUrl,
                LyricsUrl = embeddedAssets.LyricsUrl,
                ArtistId = artist?.Id,
                AlbumId = album?.Id
            };
            _context.Tracks.Add(track);
            CompleteItem(item, MusicImportItemStatus.Imported, track.Id, objectPath);
            await _context.SaveChangesAsync(cancellationToken);
            if (transaction != null) await transaction.CommitAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            if (transaction != null)
                await transaction.RollbackAsync(CancellationToken.None);
            _context.ChangeTracker.Clear();
            await TryDeleteEmbeddedAssetsAsync(embeddedAssets.NewObjectPaths);
            await TryDeleteImportObjectAsync(objectPath, item.Id, leaseOwner);
            throw;
        }
        catch (Exception exception)
        {
            if (transaction != null)
            {
                try
                {
                    await transaction.RollbackAsync(CancellationToken.None);
                }
                catch (Exception rollbackException)
                {
                    _logger.LogError(
                        "Could not roll back import metadata transaction for item {ItemId}: {ExceptionType}",
                        item.Id,
                        rollbackException.GetType().Name);
                }
            }

            var duplicateConflict = IsTrackHashUniqueViolation(exception);
            _context.ChangeTracker.Clear();
            await TryDeleteEmbeddedAssetsAsync(embeddedAssets.NewObjectPaths);
            var cleanupSucceeded = await TryDeleteImportObjectAsync(
                objectPath,
                item.Id,
                leaseOwner);
            if (duplicateConflict)
            {
                var existing = await _context.Tracks.AsNoTracking()
                    .SingleOrDefaultAsync(
                        track => track.ContentSha256 != null &&
                            track.ContentSha256.SequenceEqual(contentHash),
                        cancellationToken);
                if (existing != null)
                {
                    var conflictedItem = await LoadClaimedItemAsync(
                        item.Id,
                        leaseOwner,
                        cancellationToken);
                    if (!cleanupSucceeded)
                    {
                        await DeferRecoveredObjectCleanupAsync(
                            conflictedItem,
                            leaseOwner,
                            "CLEANUP_PENDING",
                            "The managed object could not be deleted and cleanup will be retried.",
                            cancellationToken,
                            stopHeartbeat);
                        return;
                    }
                    await CompleteDuplicateAsync(
                        conflictedItem,
                        existing.Id,
                        leaseOwner,
                        cancellationToken,
                        stopHeartbeat);
                    return;
                }
            }

            await MarkFailedAsync(
                item.Id,
                leaseOwner,
                "DATABASE_ERROR",
                retryable: true,
                "Track metadata could not be committed.",
                cleanupSucceeded ? null : objectPath,
                cancellationToken,
                stopHeartbeat);
        }
    }

    private async Task TryDeleteEmbeddedAssetsAsync(
        IReadOnlyList<string> objectPaths)
    {
        foreach (var objectPath in objectPaths)
        {
            try
            {
                if (!await _storage.DeleteFileAsync(objectPath))
                {
                    _logger.LogCritical(
                        "Immediate cleanup failed for embedded track asset {ObjectPath}",
                        objectPath);
                }
            }
            catch (Exception exception)
            {
                _logger.LogCritical(
                    "Immediate cleanup threw for embedded track asset {ObjectPath} ({ExceptionType})",
                    objectPath,
                    exception.GetType().Name);
            }
        }
    }

    private async Task<Artist?> GetOrCreateArtistAsync(
        string? artistName,
        CancellationToken cancellationToken)
    {
        var normalizedName = artistName?.Trim();
        if (string.IsNullOrEmpty(normalizedName)) return null;

        var normalizedLower = normalizedName.ToLowerInvariant();
        var artist = _context.Artists.Local.FirstOrDefault(candidate =>
                candidate.Name.Equals(normalizedName, StringComparison.OrdinalIgnoreCase))
            ?? await _context.Artists.FirstOrDefaultAsync(
                candidate => candidate.Name.ToLower() == normalizedLower,
                cancellationToken);
        if (artist != null) return artist;

        artist = new Artist { Name = normalizedName };
        _context.Artists.Add(artist);
        return artist;
    }

    private async Task<Album?> GetOrCreateAlbumAsync(
        string? albumName,
        Artist? artist,
        CancellationToken cancellationToken)
    {
        var normalizedTitle = albumName?.Trim();
        if (string.IsNullOrEmpty(normalizedTitle)) return null;

        var normalizedLower = normalizedTitle.ToLowerInvariant();
        var artistId = artist?.Id;
        var album = _context.Albums.Local.FirstOrDefault(candidate =>
                candidate.ArtistId == artistId &&
                candidate.Title.Equals(normalizedTitle, StringComparison.OrdinalIgnoreCase))
            ?? await _context.Albums.FirstOrDefaultAsync(
                candidate => candidate.ArtistId == artistId &&
                    candidate.Title.ToLower() == normalizedLower,
                cancellationToken);
        if (album != null) return album;

        album = new Album
        {
            Title = normalizedTitle,
            Artist = artist,
            ArtistId = artistId
        };
        _context.Albums.Add(album);
        return album;
    }

    private async Task<byte[]> HashSourceAsync(
        Stream source,
        MusicImportItem item,
        string leaseOwner,
        CancellationToken cancellationToken)
    {
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        var buffer = ArrayPool<byte>.Shared.Rent(128 * 1024);
        var nextRenewal = DateTime.UtcNow + RenewalInterval();
        try
        {
            int bytesRead;
            while ((bytesRead = await source.ReadAsync(
                       buffer.AsMemory(0, buffer.Length),
                       cancellationToken)) > 0)
            {
                hash.AppendData(buffer, 0, bytesRead);
                if (DateTime.UtcNow >= nextRenewal)
                {
                    await RenewLeaseAsync(item, leaseOwner, cancellationToken);
                    nextRenewal = DateTime.UtcNow + RenewalInterval();
                }
            }
            return hash.GetHashAndReset();
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer);
        }
    }

    private async Task RenewLeaseAsync(
        MusicImportItem item,
        string leaseOwner,
        CancellationToken cancellationToken)
    {
        await SynchronizeClaimAsync(item, leaseOwner, cancellationToken);
        item.LeaseExpiresAt = DateTime.UtcNow + _settings.LeaseDuration;
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task CompleteDuplicateAsync(
        MusicImportItem item,
        Guid trackId,
        string leaseOwner,
        CancellationToken cancellationToken,
        Func<Task>? stopHeartbeat)
    {
        await RenewLeaseAsync(item, leaseOwner, cancellationToken);
        if (stopHeartbeat != null) await stopHeartbeat();
        CompleteItem(item, MusicImportItemStatus.Duplicate, trackId, objectPath: null);
        await _context.SaveChangesAsync(cancellationToken);
    }

    private static void CompleteItem(
        MusicImportItem item,
        MusicImportItemStatus status,
        Guid trackId,
        string? objectPath)
    {
        item.Status = status;
        item.Stage = MusicImportItemStage.None;
        item.Retryable = false;
        item.TrackId = trackId;
        item.ObjectPath = objectPath;
        item.LeaseOwner = null;
        item.LeaseExpiresAt = null;
        item.ErrorCode = null;
        item.ErrorMessage = null;
        item.CompletedAt = DateTime.UtcNow;
    }

    private async Task MarkFailedAsync(
        Guid itemId,
        string leaseOwner,
        string errorCode,
        bool retryable,
        string errorMessage,
        string? objectPath,
        CancellationToken cancellationToken,
        Func<Task>? stopHeartbeat)
    {
        var item = await LoadClaimedItemAsync(itemId, leaseOwner, cancellationToken);
        await RenewLeaseAsync(item, leaseOwner, cancellationToken);
        if (stopHeartbeat != null) await stopHeartbeat();
        item.Status = MusicImportItemStatus.Failed;
        item.Stage = MusicImportItemStage.None;
        item.Retryable = retryable;
        item.NextAttemptAt = retryable
            ? DateTime.UtcNow.AddMinutes(Math.Min(30, Math.Max(1, item.AttemptCount)))
            : DateTime.MaxValue;
        item.ObjectPath = objectPath;
        item.LeaseOwner = null;
        item.LeaseExpiresAt = null;
        item.ErrorCode = errorCode;
        item.ErrorMessage = errorMessage;
        item.CompletedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task<MusicImportItem> LoadClaimedItemAsync(
        Guid itemId,
        string leaseOwner,
        CancellationToken cancellationToken)
    {
        var tracked = _context.ChangeTracker.Entries<MusicImportItem>()
            .Select(entry => entry.Entity)
            .SingleOrDefault(candidate => candidate.Id == itemId);
        var item = tracked ?? await _context.MusicImportItems.SingleAsync(
            candidate => candidate.Id == itemId,
            cancellationToken);
        await SynchronizeClaimAsync(item, leaseOwner, cancellationToken);
        return item;
    }

    private async Task SynchronizeClaimAsync(
        MusicImportItem item,
        string leaseOwner,
        CancellationToken cancellationToken)
    {
        if (_scopeFactory == null)
        {
            ValidateClaim(item, leaseOwner);
            return;
        }

        var now = DateTime.UtcNow;
        var claim = await _context.MusicImportItems
            .AsNoTracking()
            .Where(candidate => candidate.Id == item.Id &&
                candidate.Status == MusicImportItemStatus.Processing &&
                candidate.LeaseOwner == leaseOwner &&
                candidate.LeaseExpiresAt > now)
            .Select(candidate => new
            {
                candidate.Version,
                candidate.LeaseExpiresAt
            })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new InvalidOperationException(
                "The music import item lease is no longer owned by this worker.");

        var entry = _context.Entry(item);
        entry.Property(candidate => candidate.Version).OriginalValue = claim.Version;
        entry.Property(candidate => candidate.Version).CurrentValue = claim.Version;
        entry.Property(candidate => candidate.LeaseExpiresAt).CurrentValue = claim.LeaseExpiresAt;
        entry.Property(candidate => candidate.LeaseExpiresAt).IsModified = false;
    }

    private FileInfo ValidateSafeSourceFile(
        ResolvedMusicImportPath resolved,
        MusicImportItem item)
    {
        var root = new DirectoryInfo(Path.GetFullPath(_settings.SourceRoot));
        if (!root.Exists)
            throw new ProcessingFailureException(
                "SOURCE_MISSING", false, "The configured import source is unavailable.");
        if (MusicImportPathPolicy.IsReparsePoint(root))
            throw new ProcessingFailureException(
                "SOURCE_REPARSE_POINT", false, "Import source reparse points are not allowed.");

        var segments = resolved.RelativePath.Split('/');
        var current = root;
        foreach (var segment in segments[..^1])
        {
            current = new DirectoryInfo(Path.Combine(current.FullName, segment));
            if (!current.Exists)
                throw new ProcessingFailureException(
                    "SOURCE_MISSING", false, "A source directory is unavailable.");
            if (MusicImportPathPolicy.IsReparsePoint(current))
                throw new ProcessingFailureException(
                    "SOURCE_REPARSE_POINT", false, "Source directory reparse points are not allowed.");
        }

        var file = new FileInfo(resolved.FullPath);
        if (!file.Exists)
            throw new ProcessingFailureException(
                "SOURCE_MISSING", false, "The source file is unavailable.");
        if (MusicImportPathPolicy.IsReparsePoint(file))
            throw new ProcessingFailureException(
                "SOURCE_REPARSE_POINT", false, "Source file reparse points are not allowed.");
        EnsureSourceSnapshot(file, source: null, item);
        return file;
    }

    private static void EnsureSourceSnapshot(
        FileInfo file,
        Stream? source,
        MusicImportItem item)
    {
        file.Refresh();
        if (!file.Exists || MusicImportPathPolicy.IsReparsePoint(file))
            throw new ProcessingFailureException(
                "SOURCE_REPARSE_POINT", false, "The source path changed or became unsafe.");
        var modifiedAt = MusicImportScanner.NormalizeDatabaseTimestamp(file.LastWriteTimeUtc);
        if (file.Length != item.SizeBytes ||
            modifiedAt != item.SourceModifiedAt ||
            (source != null && source.Length != item.SizeBytes))
        {
            throw new ProcessingFailureException(
                "SOURCE_CHANGED", false, "The source size or modification time changed after scanning.");
        }
    }

    private static void ValidateMetadata(AudioMetadata metadata)
    {
        if (string.IsNullOrWhiteSpace(metadata.Title) ||
            metadata.DurationSeconds <= 0 ||
            metadata.BitRate < 0 ||
            string.IsNullOrWhiteSpace(metadata.Format))
        {
            throw new ProcessingFailureException(
                "INVALID_METADATA", false, "Required audio metadata is invalid.");
        }
    }

    private static void ValidateClaim(
        MusicImportItem item,
        string leaseOwner)
    {
        if (item.Status != MusicImportItemStatus.Processing ||
            string.IsNullOrWhiteSpace(leaseOwner) ||
            !string.Equals(item.LeaseOwner, leaseOwner, StringComparison.Ordinal) ||
            item.LeaseExpiresAt is not DateTime leaseExpiresAt ||
            leaseExpiresAt <= DateTime.UtcNow)
        {
            throw new InvalidOperationException("The music import item lease is not owned by this worker.");
        }
    }

    private async Task<bool> TryDeleteImportObjectAsync(
        string objectPath,
        Guid itemId,
        string leaseOwner)
    {
        if (!await TryRenewCleanupOwnershipAsync(itemId, leaseOwner))
        {
            _logger.LogWarning(
                "Skipped cleanup for deterministic import object {ObjectPath} because item {ItemId} ownership could not be confirmed",
                objectPath,
                itemId);
            return false;
        }

        try
        {
            if (!await _storage.DeleteFileAsync(objectPath))
            {
                _logger.LogCritical(
                    "Immediate cleanup failed for deterministic import object {ObjectPath}; no asynchronous delete was queued",
                    objectPath);
                return false;
            }
            return true;
        }
        catch (Exception exception)
        {
            _logger.LogCritical(
                "Immediate cleanup threw for deterministic import object {ObjectPath}; no asynchronous delete was queued ({ExceptionType})",
                objectPath,
                exception.GetType().Name);
            return false;
        }
    }

    private async Task<bool> TryRenewCleanupOwnershipAsync(
        Guid itemId,
        string leaseOwner)
    {
        var now = DateTime.UtcNow;
        var leaseExpiresAt = now + _settings.LeaseDuration;
        try
        {
            if (_context.Database.IsRelational())
            {
                var updated = await _context.MusicImportItems
                    .Where(item => item.Id == itemId &&
                        item.Status == MusicImportItemStatus.Processing &&
                        item.LeaseOwner == leaseOwner &&
                        item.LeaseExpiresAt > now)
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(item => item.LeaseExpiresAt, leaseExpiresAt)
                        .SetProperty(item => item.UpdatedAt, now)
                        .SetProperty(item => item.Version, item => item.Version + 1),
                        CancellationToken.None);
                if (updated != 1) return false;

                var tracked = _context.ChangeTracker.Entries<MusicImportItem>()
                    .SingleOrDefault(entry => entry.Entity.Id == itemId);
                if (tracked != null) await tracked.ReloadAsync(CancellationToken.None);
                return true;
            }

            var item = _context.ChangeTracker.Entries<MusicImportItem>()
                    .Select(entry => entry.Entity)
                    .SingleOrDefault(candidate => candidate.Id == itemId)
                ?? await _context.MusicImportItems.SingleOrDefaultAsync(
                    candidate => candidate.Id == itemId,
                    CancellationToken.None);
            if (item == null ||
                item.Status != MusicImportItemStatus.Processing ||
                !string.Equals(item.LeaseOwner, leaseOwner, StringComparison.Ordinal) ||
                item.LeaseExpiresAt is not DateTime currentLeaseExpiry ||
                currentLeaseExpiry <= now)
            {
                return false;
            }

            item.LeaseExpiresAt = leaseExpiresAt;
            await _context.SaveChangesAsync(CancellationToken.None);
            return true;
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                "Could not confirm cleanup ownership for import item {ItemId}: {ExceptionType}",
                itemId,
                exception.GetType().Name);
            return false;
        }
    }

    internal static bool IsTrackHashUniqueViolation(Exception exception) =>
        exception is DbUpdateException
        {
            InnerException: PostgresException
            {
                SqlState: PostgresErrorCodes.UniqueViolation,
                ConstraintName: TrackHashUniqueConstraintName
            }
        };

    private TimeSpan RenewalInterval()
    {
        var interval = TimeSpan.FromTicks(_settings.LeaseDuration.Ticks / 3);
        return interval < TimeSpan.FromSeconds(1)
            ? TimeSpan.FromSeconds(1)
            : interval;
    }

    private void EnsureEnabled()
    {
        if (!_settings.Enabled)
            throw new InvalidOperationException("Music library import is disabled.");
        if (_settings.LeaseDuration <= TimeSpan.Zero)
            throw new InvalidOperationException("Music import lease duration must be positive.");
    }

    private sealed class ProcessingFailureException : Exception
    {
        public ProcessingFailureException(
            string code,
            bool retryable,
            string message,
            Exception? innerException = null) : base(message, innerException)
        {
            Code = code;
            Retryable = retryable;
        }

        public string Code { get; }
        public bool Retryable { get; }
    }

    private sealed class LeaseHeartbeatState
    {
        public Exception? Failure { get; set; }
    }

    private sealed class VerifyingReadStream : Stream
    {
        private readonly Stream _inner;
        private readonly IncrementalHash _hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        private readonly TimeSpan _renewalInterval;
        private readonly Func<CancellationToken, Task> _renewLease;
        private DateTime _nextRenewal;
        private bool _hashRead;

        public VerifyingReadStream(
            Stream inner,
            TimeSpan leaseDuration,
            Func<CancellationToken, Task> renewLease)
        {
            _inner = inner;
            _renewalInterval = TimeSpan.FromTicks(Math.Max(
                TimeSpan.FromSeconds(1).Ticks,
                leaseDuration.Ticks / 3));
            _nextRenewal = DateTime.UtcNow + _renewalInterval;
            _renewLease = renewLease;
        }

        public long BytesRead { get; private set; }
        public override bool CanRead => _inner.CanRead;
        public override bool CanSeek => _inner.CanSeek;
        public override bool CanWrite => false;
        public override long Length => _inner.Length;

        public override long Position
        {
            get => _inner.Position;
            set
            {
                if (value != _inner.Position)
                    throw new NotSupportedException("Upload verification stream cannot be repositioned.");
            }
        }

        public byte[] GetHash()
        {
            if (_hashRead) throw new InvalidOperationException("Upload hash has already been read.");
            _hashRead = true;
            return _hash.GetHashAndReset();
        }

        public override async ValueTask<int> ReadAsync(
            Memory<byte> buffer,
            CancellationToken cancellationToken = default)
        {
            await RenewIfDueAsync(cancellationToken);
            var bytesRead = await _inner.ReadAsync(buffer, cancellationToken);
            Append(buffer.Span[..bytesRead]);
            return bytesRead;
        }

        public override int Read(byte[] buffer, int offset, int count)
        {
            RenewIfDueAsync(CancellationToken.None).GetAwaiter().GetResult();
            var bytesRead = _inner.Read(buffer, offset, count);
            Append(buffer.AsSpan(offset, bytesRead));
            return bytesRead;
        }

        private void Append(ReadOnlySpan<byte> bytes)
        {
            if (bytes.Length == 0) return;
            _hash.AppendData(bytes);
            BytesRead += bytes.Length;
        }

        private async Task RenewIfDueAsync(CancellationToken cancellationToken)
        {
            if (DateTime.UtcNow < _nextRenewal) return;
            await _renewLease(cancellationToken);
            _nextRenewal = DateTime.UtcNow + _renewalInterval;
        }

        public override long Seek(long offset, SeekOrigin origin)
        {
            var target = origin switch
            {
                SeekOrigin.Begin => offset,
                SeekOrigin.Current => checked(Position + offset),
                SeekOrigin.End => checked(Length + offset),
                _ => throw new ArgumentOutOfRangeException(nameof(origin))
            };
            if (target != Position)
                throw new NotSupportedException("Upload verification stream cannot be repositioned.");
            return Position;
        }

        public override void Flush() { }
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();

        protected override void Dispose(bool disposing)
        {
            if (disposing) _hash.Dispose();
            base.Dispose(disposing);
        }
    }
}
