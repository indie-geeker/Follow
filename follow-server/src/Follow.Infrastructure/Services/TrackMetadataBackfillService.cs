using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

public sealed class TrackMetadataBackfillService
{
    private readonly FollowDbContext _context;
    private readonly IStorageService _storage;
    private readonly IAudioMetadataExtractor _extractor;
    private readonly EmbeddedTrackAssetWriter _assetWriter;
    private readonly StorageDeletionQueue _deletionQueue;
    private readonly Func<string> _temporaryPathFactory;

    public TrackMetadataBackfillService(
        FollowDbContext context,
        IStorageService storage,
        IAudioMetadataExtractor extractor,
        EmbeddedTrackAssetWriter assetWriter,
        StorageDeletionQueue deletionQueue,
        Func<string>? temporaryPathFactory = null)
    {
        _context = context;
        _storage = storage;
        _extractor = extractor;
        _assetWriter = assetWriter;
        _deletionQueue = deletionQueue;
        _temporaryPathFactory = temporaryPathFactory ?? (() => Path.Combine(
            Path.GetTempPath(),
            $"follow-metadata-backfill-{Guid.NewGuid():N}.tmp"));
    }

    public async Task<TrackMetadataBackfillResponse> RunAsync(
        TrackMetadataBackfillRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.Limit is < 1 or > 100)
            throw new ArgumentOutOfRangeException(
                nameof(request.Limit),
                "Limit must be between 1 and 100.");

        var query = _context.Tracks
            .AsNoTracking()
            .Where(track => track.CoverUrl == null || track.LyricsUrl == null);
        if (request.AfterId.HasValue)
        {
            var afterId = request.AfterId.Value;
            query = query.Where(track => track.Id.CompareTo(afterId) > 0);
        }

        var candidates = await query
            .OrderBy(track => track.Id)
            .Take(request.Limit)
            .ToListAsync(cancellationToken);
        var entries = new List<TrackMetadataBackfillEntryDto>(candidates.Count);

        foreach (var track in candidates)
        {
            cancellationToken.ThrowIfCancellationRequested();
            entries.Add(await ProcessTrackAsync(track, request.DryRun, cancellationToken));
        }

        return new TrackMetadataBackfillResponse(
            request.DryRun,
            candidates.Count,
            entries.Count(entry => entry.CoverAvailable),
            entries.Count(entry => entry.LyricsAvailable),
            entries.Count(entry => entry.CoverUpdated || entry.LyricsUpdated),
            entries.Count(entry => entry.Status == "failed"),
            candidates.Count == 0 ? null : candidates[^1].Id,
            entries);
    }

    private async Task<TrackMetadataBackfillEntryDto> ProcessTrackAsync(
        Track track,
        bool dryRun,
        CancellationToken cancellationToken)
    {
        AudioMetadata metadata;
        var temporaryPath = _temporaryPathFactory();
        try
        {
            var objectMetadata = await _storage.GetObjectMetadataAsync(
                track.FilePath,
                cancellationToken);
            if (objectMetadata == null)
                return Failed(track.Id, "AUDIO_NOT_FOUND");

            await using var temporaryFile = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.ReadWrite,
                FileShare.None,
                64 * 1024,
                FileOptions.Asynchronous | FileOptions.SequentialScan);
            await _storage.CopyRangeToAsync(
                track.FilePath,
                0,
                objectMetadata.Length,
                temporaryFile,
                cancellationToken);
            temporaryFile.Position = 0;
            metadata = await _extractor.ExtractAsync(
                temporaryFile,
                track.OriginalFileName ?? Path.GetFileName(track.FilePath),
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch
        {
            return Failed(track.Id, "EXTRACTION_FAILED");
        }
        finally
        {
            if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
        }

        var coverAvailable = track.CoverUrl == null &&
            EmbeddedTrackAssetWriter.IsSupportedCover(
                metadata.CoverData,
                metadata.CoverContentType);
        var timedLyrics = track.LyricsUrl == null
            ? EmbeddedLyricsPolicy.Normalize(metadata.TimedLyrics)
            : null;
        var lyricsAvailable = timedLyrics != null;

        if (dryRun || (!coverAvailable && !lyricsAvailable))
        {
            return new TrackMetadataBackfillEntryDto(
                track.Id,
                dryRun ? "dryRun" : "noSupportedAssets",
                coverAvailable,
                lyricsAvailable,
                false,
                false,
                null);
        }

        EmbeddedTrackAssetResult assets;
        try
        {
            assets = await _assetWriter.WriteAsync(
                track.Id,
                coverAvailable ? metadata.CoverData : null,
                coverAvailable ? metadata.CoverContentType : null,
                timedLyrics,
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch
        {
            return Failed(
                track.Id,
                "ASSET_WRITE_FAILED",
                coverAvailable,
                lyricsAvailable);
        }

        try
        {
            var (coverUpdated, lyricsUpdated) = await PersistMissingReferencesAsync(
                track.Id,
                assets,
                cancellationToken);
            if (!coverUpdated && !lyricsUpdated)
            {
                await CompensateAsync(assets.NewObjectPaths);
            }

            return new TrackMetadataBackfillEntryDto(
                track.Id,
                coverUpdated || lyricsUpdated ? "updated" : "concurrentUpdateWon",
                coverAvailable,
                lyricsAvailable,
                coverUpdated,
                lyricsUpdated,
                null);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            _context.ChangeTracker.Clear();
            await CompensateAsync(assets.NewObjectPaths);
            throw;
        }
        catch
        {
            _context.ChangeTracker.Clear();
            await CompensateAsync(assets.NewObjectPaths);
            return Failed(
                track.Id,
                "DATABASE_WRITE_FAILED",
                coverAvailable,
                lyricsAvailable);
        }
    }

    private async Task<(bool CoverUpdated, bool LyricsUpdated)> PersistMissingReferencesAsync(
        Guid trackId,
        EmbeddedTrackAssetResult assets,
        CancellationToken cancellationToken)
    {
        if (_context.Database.IsRelational())
        {
            var query = _context.Tracks.Where(track => track.Id == trackId);
            if (assets.CoverUrl != null && assets.LyricsUrl != null)
            {
                var updated = await query
                    .Where(track => track.CoverUrl == null && track.LyricsUrl == null)
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(track => track.CoverUrl, assets.CoverUrl)
                        .SetProperty(track => track.LyricsUrl, assets.LyricsUrl)
                        .SetProperty(track => track.UpdatedAt, DateTime.UtcNow),
                        cancellationToken);
                return (updated == 1, updated == 1);
            }

            if (assets.CoverUrl != null)
            {
                var updated = await query
                    .Where(track => track.CoverUrl == null)
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(track => track.CoverUrl, assets.CoverUrl)
                        .SetProperty(track => track.UpdatedAt, DateTime.UtcNow),
                        cancellationToken);
                return (updated == 1, false);
            }

            var updatedLyricsRows = await query
                .Where(track => track.LyricsUrl == null)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(track => track.LyricsUrl, assets.LyricsUrl)
                    .SetProperty(track => track.UpdatedAt, DateTime.UtcNow),
                    cancellationToken);
            return (false, updatedLyricsRows == 1);
        }

        _context.ChangeTracker.Clear();
        var current = await _context.Tracks.SingleOrDefaultAsync(
            track => track.Id == trackId,
            cancellationToken);
        if (current == null) return (false, false);

        var coverUpdated = current.CoverUrl == null && assets.CoverUrl != null;
        var lyricsUpdated = current.LyricsUrl == null && assets.LyricsUrl != null;
        if (coverUpdated) current.CoverUrl = assets.CoverUrl;
        if (lyricsUpdated) current.LyricsUrl = assets.LyricsUrl;
        if (coverUpdated || lyricsUpdated)
        {
            current.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);
        }
        return (coverUpdated, lyricsUpdated);
    }

    private async Task CompensateAsync(IReadOnlyList<string> objectPaths)
    {
        foreach (var objectPath in objectPaths)
        {
            await _deletionQueue.CompensateUploadAsync(_storage, objectPath);
        }
    }

    private static TrackMetadataBackfillEntryDto Failed(
        Guid trackId,
        string errorCode,
        bool coverAvailable = false,
        bool lyricsAvailable = false) => new(
            trackId,
            "failed",
            coverAvailable,
            lyricsAvailable,
            false,
            false,
            errorCode);
}
