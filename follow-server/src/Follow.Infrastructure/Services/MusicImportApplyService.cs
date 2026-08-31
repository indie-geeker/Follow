using System.Security.Cryptography;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

public sealed class MusicImportApplyService : IMusicImportApplyService
{
    private readonly FollowDbContext _context;
    private readonly IMusicImportSourceReader _sourceReader;
    private readonly IAudioFingerprintService _fingerprintService;
    private readonly IStorageService _storage;
    private readonly StorageDeletionQueue _deletionQueue;

    public MusicImportApplyService(
        FollowDbContext context,
        IMusicImportSourceReader sourceReader,
        IAudioFingerprintService fingerprintService,
        IStorageService storage,
        StorageDeletionQueue deletionQueue)
    {
        _context = context;
        _sourceReader = sourceReader;
        _fingerprintService = fingerprintService;
        _storage = storage;
        _deletionQueue = deletionQueue;
    }

    public async Task<MusicImportApplyResult> ApplyGroupAsync(
        Guid groupId,
        int expectedVersion,
        CancellationToken cancellationToken = default)
    {
        var group = await _context.MusicImportReviewGroups
            .Include(candidate => candidate.Batch)
            .Include(candidate => candidate.Items)
            .SingleOrDefaultAsync(candidate => candidate.Id == groupId, cancellationToken)
            ?? throw new KeyNotFoundException("Music import review group was not found.");
        if (group.Version != expectedVersion)
            throw new MusicImportApplyConflictException(group.Version);

        if (group.Status == MusicImportReviewStatus.Applied)
        {
            var appliedTrackIds = group.Items
                .Where(item => item.TrackId != null)
                .Select(item => item.TrackId!.Value)
                .Distinct()
                .Order()
                .ToArray();
            if (appliedTrackIds.Length == 0)
                throw new MusicImportApplyValidationException(
                    "Applied review group has no durable Track result.");
            return new MusicImportApplyResult(
                group.Id,
                appliedTrackIds[0],
                true,
                appliedTrackIds);
        }

        if (group.Status != MusicImportReviewStatus.Locked ||
            group.Batch.Status != MusicImportBatchStatus.Applying)
        {
            throw new InvalidOperationException(
                "Only a locked group in an applying batch can mutate the library.");
        }

        if (group.Items.Count == 0 ||
            group.Items.Any(item => item.Decision == null) ||
            group.ConfirmedByUserId == null)
        {
            throw new MusicImportApplyValidationException(
                "The group has no complete explicit decision.");
        }

        var decisions = group.Items
            .Select(item => item.Decision!.Value)
            .Distinct()
            .ToArray();
        if (decisions.Length == 1 && decisions[0] is
            MusicImportDecisionKind.KeepExistingTrack or
            MusicImportDecisionKind.RejectDuplicate)
        {
            return await PersistExistingTrackDecisionAsync(
                group,
                decisions[0],
                cancellationToken);
        }
        if (decisions.Length == 1 &&
            decisions[0] == MusicImportDecisionKind.TreatAsSeparateRecording)
        {
            if (group.MatchKind == MusicImportMatchKind.ExactSha256)
            {
                throw new MusicImportApplyValidationException(
                    "Byte-identical candidates cannot be treated as separate recordings.");
            }
            return await ApplySeparateRecordingsAsync(
                group,
                expectedVersion,
                cancellationToken);
        }

        var selectedForCreate = group.Items
            .Where(item => item.Decision == MusicImportDecisionKind.CreateTrack)
            .ToArray();
        var selectedForReplacement = group.Items
            .Where(item => item.Decision == MusicImportDecisionKind.ReplaceExistingTrack)
            .ToArray();
        var replacing = selectedForReplacement.Length == 1 && selectedForCreate.Length == 0;
        if ((!replacing && selectedForCreate.Length != 1) ||
            (replacing && (group.ExistingTrackId == null ||
                selectedForReplacement[0].DecisionTrackId != group.ExistingTrackId)) ||
            group.Items.Any(item => item.Decision is not (
                MusicImportDecisionKind.CreateTrack or
                MusicImportDecisionKind.ReplaceExistingTrack or
                MusicImportDecisionKind.RejectDuplicate)))
        {
            throw new MusicImportApplyValidationException(
                "The group has no complete explicit create-Track decision.");
        }
        var selectedItem = replacing ? selectedForReplacement[0] : selectedForCreate[0];
        await using var source = await OpenAndValidateSourceAsync(
            selectedItem,
            cancellationToken);
        if (!AudioFilePolicy.TryGetCanonicalContentType(
                selectedItem.OriginalFileName,
                out var contentType))
        {
            throw new MusicImportApplyValidationException("Selected candidate format is unsupported.");
        }

        var objectPath = ImportObjectPath.BuildRevision(
            group.Id,
            expectedVersion,
            selectedItem.Id,
            selectedItem.Extension);
        source.Stream.Position = 0;
        await _storage.WriteObjectAsync(
            objectPath,
            source.Stream,
            selectedItem.SizeBytes,
            contentType,
            cancellationToken);
        try
        {
            await VerifyStoredObjectAsync(
                objectPath,
                selectedItem.SizeBytes,
                selectedItem.ContentSha256!,
                cancellationToken);
            return replacing
                ? await PersistReplacementAsync(
                    group,
                    selectedItem,
                    objectPath,
                    cancellationToken)
                : await PersistNewTrackAsync(
                    group,
                    selectedItem,
                    objectPath,
                    cancellationToken);
        }
        catch
        {
            await CompensateUnlessReferencedAsync(objectPath);
            throw;
        }
    }

    private async Task<MusicImportApplyResult> PersistExistingTrackDecisionAsync(
        MusicImportReviewGroup group,
        MusicImportDecisionKind decision,
        CancellationToken cancellationToken)
    {
        if (group.ExistingTrackId is not Guid existingTrackId ||
            group.Items.Any(item => item.DecisionTrackId != existingTrackId))
        {
            throw new MusicImportApplyValidationException(
                "The existing Track decision is incomplete.");
        }

        await using var transaction = _context.Database.IsRelational()
            ? await _context.Database.BeginTransactionAsync(cancellationToken)
            : null;
        try
        {
            var exists = await _context.Tracks.AnyAsync(
                track => track.Id == existingTrackId,
                cancellationToken);
            if (!exists)
                throw new MusicImportApplyValidationException(
                    "The existing Track no longer exists.");

            foreach (var item in group.Items)
            {
                item.TrackId = existingTrackId;
                item.ObjectPath = null;
                item.Status = MusicImportItemStatus.Duplicate;
                MarkVerified(item);
                QueueStagingCleanup(item);
            }
            group.Status = MusicImportReviewStatus.Applied;
            await _context.SaveChangesAsync(cancellationToken);
            if (transaction != null) await transaction.CommitAsync(cancellationToken);
            return new MusicImportApplyResult(group.Id, existingTrackId, false);
        }
        catch
        {
            if (transaction != null)
                await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    private async Task<MusicImportApplyResult> ApplySeparateRecordingsAsync(
        MusicImportReviewGroup group,
        int expectedVersion,
        CancellationToken cancellationToken)
    {
        var prepared = new List<PreparedRecording>(group.Items.Count);
        var attemptedObjectPaths = new List<string>(group.Items.Count);
        try
        {
            foreach (var item in group.Items.OrderBy(item => item.Id))
            {
                await using var source = await OpenAndValidateSourceAsync(item, cancellationToken);
                if (!AudioFilePolicy.TryGetCanonicalContentType(item.OriginalFileName, out var contentType))
                {
                    throw new MusicImportApplyValidationException(
                        "Selected candidate format is unsupported.");
                }

                var objectPath = ImportObjectPath.BuildRevision(
                    group.Id,
                    expectedVersion,
                    item.Id,
                    item.Extension);
                attemptedObjectPaths.Add(objectPath);
                source.Stream.Position = 0;
                await _storage.WriteObjectAsync(
                    objectPath,
                    source.Stream,
                    item.SizeBytes,
                    contentType,
                    cancellationToken);
                await VerifyStoredObjectAsync(
                    objectPath,
                    item.SizeBytes,
                    item.ContentSha256!,
                    cancellationToken);
                prepared.Add(new PreparedRecording(item, objectPath));
            }

            return await PersistSeparateTracksAsync(group, prepared, cancellationToken);
        }
        catch
        {
            foreach (var objectPath in attemptedObjectPaths)
                await CompensateUnlessReferencedAsync(objectPath);
            throw;
        }
    }

    private async Task<MusicImportApplyResult> PersistSeparateTracksAsync(
        MusicImportReviewGroup group,
        IReadOnlyCollection<PreparedRecording> recordings,
        CancellationToken cancellationToken)
    {
        await using var transaction = _context.Database.IsRelational()
            ? await _context.Database.BeginTransactionAsync(cancellationToken)
            : null;
        try
        {
            var trackIds = new List<Guid>(recordings.Count);
            foreach (var recording in recordings)
            {
                var selected = recording.Item;
                var artist = await GetOrCreateArtistAsync(selected.ExtractedArtist, cancellationToken);
                var album = await GetOrCreateAlbumAsync(selected.ExtractedAlbum, artist, cancellationToken);
                var track = CreateTrack(selected, recording.ObjectPath, artist, album);
                _context.Tracks.Add(track);
                selected.TrackId = track.Id;
                selected.ObjectPath = recording.ObjectPath;
                selected.Status = MusicImportItemStatus.Imported;
                MarkVerified(selected);
                QueueStagingCleanup(selected);
                trackIds.Add(track.Id);
            }

            group.MatchKind = MusicImportMatchKind.UserSeparated;
            group.Status = MusicImportReviewStatus.Applied;
            await _context.SaveChangesAsync(cancellationToken);
            if (transaction != null) await transaction.CommitAsync(cancellationToken);
            return new MusicImportApplyResult(group.Id, trackIds[0], false, trackIds);
        }
        catch
        {
            if (transaction != null)
                await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    private static Track CreateTrack(
        MusicImportItem selected,
        string objectPath,
        Artist? artist,
        Album? album) => new()
    {
        Title = selected.ExtractedTitle?.Trim() ??
            Path.GetFileNameWithoutExtension(selected.OriginalFileName),
        DurationSeconds = checked((int)Math.Round(
            selected.ExactDurationMilliseconds!.Value / 1000d)),
        FilePath = objectPath,
        BitRate = selected.BitRateKbps ?? 0,
        Format = selected.Container ?? selected.Extension.TrimStart('.'),
        ContentSha256 = selected.ContentSha256,
        FileSizeBytes = selected.SizeBytes,
        OriginalFileName = selected.OriginalFileName,
        Codec = selected.Codec,
        Container = selected.Container,
        IsLossless = selected.IsLossless,
        SampleRateHz = selected.SampleRateHz,
        BitDepth = selected.BitDepth,
        Channels = selected.Channels,
        BitRateKbps = selected.BitRateKbps,
        ExactDurationMilliseconds = selected.ExactDurationMilliseconds,
        FingerprintVersion = selected.FingerprintVersion,
        FingerprintAlgorithm = selected.FingerprintAlgorithm,
        FingerprintPayload = selected.FingerprintPayload,
        FingerprintFrameCount = selected.FingerprintFrameCount,
        FingerprintDurationMilliseconds = selected.FingerprintDurationMilliseconds,
        Artist = artist,
        ArtistId = artist?.Id,
        Album = album,
        AlbumId = album?.Id
    };

    private static void MarkVerified(MusicImportItem item)
    {
        item.Stage = MusicImportItemStage.Verified;
        item.CompletedAt = DateTime.UtcNow;
        item.Retryable = false;
        item.ErrorCode = null;
        item.ErrorMessage = null;
    }

    private void QueueStagingCleanup(MusicImportItem item)
    {
        if (item.SourceKind == MusicImportSourceKind.BrowserStaging &&
            item.SourceReference is { } stagingPath &&
            ImportObjectPath.IsStaging(stagingPath))
        {
            _deletionQueue.Enqueue(stagingPath);
        }
    }

    private sealed record PreparedRecording(MusicImportItem Item, string ObjectPath);

    private async Task<MusicImportSourceReadHandle> OpenAndValidateSourceAsync(
        MusicImportItem item,
        CancellationToken cancellationToken)
    {
        if (item.ContentSha256 is not { Length: 32 } expectedHash ||
            item.FingerprintPayload == null ||
            item.FingerprintFrameCount == null ||
            item.FingerprintAlgorithm == null ||
            string.IsNullOrWhiteSpace(item.FingerprintVersion) ||
            item.FingerprintDurationMilliseconds == null ||
            item.ExactDurationMilliseconds == null)
        {
            throw new MusicImportApplyValidationException(
                "Selected candidate analysis facts are incomplete.");
        }

        var snapshot = new MusicImportSourceSnapshot(
            item.SourceKind,
            item.SourceReference ?? item.RelativePath,
            item.SizeBytes,
            item.SourceKind == MusicImportSourceKind.MountedDirectory
                ? item.SourceModifiedAt
                : null,
            item.SourceETag);
        var handle = await _sourceReader.OpenReadAsync(snapshot, cancellationToken);
        try
        {
            if (!handle.Stream.CanSeek)
                throw new MusicImportApplyValidationException("Selected source is not seekable.");
            handle.Stream.Position = 0;
            var actualHash = await SHA256.HashDataAsync(handle.Stream, cancellationToken);
            if (!actualHash.SequenceEqual(expectedHash))
                throw new MusicImportApplyValidationException("Selected source SHA-256 changed.");

            handle.Stream.Position = 0;
            var actualFingerprint = await _fingerprintService.ExtractAsync(
                handle.Stream,
                TimeSpan.FromMilliseconds(item.ExactDurationMilliseconds.Value),
                cancellationToken);
            var actualPayload = AudioFingerprintPayloadCodec.Encode(actualFingerprint.Frames);
            if (actualFingerprint.Algorithm != item.FingerprintAlgorithm ||
                !string.Equals(
                    actualFingerprint.Version,
                    item.FingerprintVersion,
                    StringComparison.Ordinal) ||
                actualFingerprint.Frames.Count != item.FingerprintFrameCount ||
                checked((long)Math.Round(actualFingerprint.SourceDuration.TotalMilliseconds)) !=
                    item.FingerprintDurationMilliseconds ||
                !actualPayload.SequenceEqual(item.FingerprintPayload))
            {
                throw new MusicImportApplyValidationException(
                    "Selected source acoustic fingerprint changed.");
            }
            return handle;
        }
        catch
        {
            await handle.DisposeAsync();
            throw;
        }
    }

    private async Task VerifyStoredObjectAsync(
        string objectPath,
        long expectedLength,
        byte[] expectedHash,
        CancellationToken cancellationToken)
    {
        var metadata = await _storage.GetObjectMetadataAsync(objectPath, cancellationToken);
        if (metadata == null || metadata.Length != expectedLength)
            throw new MusicImportApplyValidationException("Stored Track object length is invalid.");

        using var sha = SHA256.Create();
        await using (var hashing = new CryptoStream(Stream.Null, sha, CryptoStreamMode.Write))
        {
            await _storage.CopyRangeToAsync(
                objectPath,
                0,
                expectedLength,
                hashing,
                cancellationToken);
            hashing.FlushFinalBlock();
        }
        if (sha.Hash == null || !sha.Hash.SequenceEqual(expectedHash))
            throw new MusicImportApplyValidationException("Stored Track object hash is invalid.");
    }

    private async Task<MusicImportApplyResult> PersistNewTrackAsync(
        MusicImportReviewGroup group,
        MusicImportItem selected,
        string objectPath,
        CancellationToken cancellationToken)
    {
        await using var transaction = _context.Database.IsRelational()
            ? await _context.Database.BeginTransactionAsync(cancellationToken)
            : null;
        try
        {
            var artist = await GetOrCreateArtistAsync(selected.ExtractedArtist, cancellationToken);
            var album = await GetOrCreateAlbumAsync(
                selected.ExtractedAlbum,
                artist,
                cancellationToken);
            var track = new Track
            {
                Title = selected.ExtractedTitle?.Trim() ??
                    Path.GetFileNameWithoutExtension(selected.OriginalFileName),
                DurationSeconds = checked((int)Math.Round(
                    selected.ExactDurationMilliseconds!.Value / 1000d)),
                FilePath = objectPath,
                BitRate = selected.BitRateKbps ?? 0,
                Format = selected.Container ?? selected.Extension.TrimStart('.'),
                ContentSha256 = selected.ContentSha256,
                FileSizeBytes = selected.SizeBytes,
                OriginalFileName = selected.OriginalFileName,
                Codec = selected.Codec,
                Container = selected.Container,
                IsLossless = selected.IsLossless,
                SampleRateHz = selected.SampleRateHz,
                BitDepth = selected.BitDepth,
                Channels = selected.Channels,
                BitRateKbps = selected.BitRateKbps,
                ExactDurationMilliseconds = selected.ExactDurationMilliseconds,
                FingerprintVersion = selected.FingerprintVersion,
                FingerprintAlgorithm = selected.FingerprintAlgorithm,
                FingerprintPayload = selected.FingerprintPayload,
                FingerprintFrameCount = selected.FingerprintFrameCount,
                FingerprintDurationMilliseconds = selected.FingerprintDurationMilliseconds,
                Artist = artist,
                ArtistId = artist?.Id,
                Album = album,
                AlbumId = album?.Id
            };
            _context.Tracks.Add(track);
            foreach (var item in group.Items)
            {
                item.TrackId = track.Id;
                item.ObjectPath = ReferenceEquals(item, selected) ? objectPath : null;
                item.Status = ReferenceEquals(item, selected)
                    ? MusicImportItemStatus.Imported
                    : MusicImportItemStatus.Duplicate;
                item.Stage = MusicImportItemStage.Verified;
                item.CompletedAt = DateTime.UtcNow;
                item.Retryable = false;
                item.ErrorCode = null;
                item.ErrorMessage = null;
                if (item.SourceKind == MusicImportSourceKind.BrowserStaging &&
                    item.SourceReference is { } stagingPath &&
                    ImportObjectPath.IsStaging(stagingPath))
                {
                    _deletionQueue.Enqueue(stagingPath);
                }
            }
            group.Status = MusicImportReviewStatus.Applied;
            await _context.SaveChangesAsync(cancellationToken);
            if (transaction != null) await transaction.CommitAsync(cancellationToken);
            return new MusicImportApplyResult(group.Id, track.Id, false);
        }
        catch
        {
            if (transaction != null)
                await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    private async Task<MusicImportApplyResult> PersistReplacementAsync(
        MusicImportReviewGroup group,
        MusicImportItem selected,
        string objectPath,
        CancellationToken cancellationToken)
    {
        await using var transaction = _context.Database.IsRelational()
            ? await _context.Database.BeginTransactionAsync(cancellationToken)
            : null;
        try
        {
            var track = await _context.Tracks.SingleOrDefaultAsync(
                candidate => candidate.Id == group.ExistingTrackId,
                cancellationToken)
                ?? throw new MusicImportApplyValidationException(
                    "The existing Track selected for replacement no longer exists.");
            var oldObjectPath = track.FilePath;
            var deletionJob = StorageDeletionQueue.IsManagedObjectPath(oldObjectPath) &&
                !string.Equals(oldObjectPath, objectPath, StringComparison.Ordinal)
                ? new StorageDeletionJob
                {
                    ObjectPath = oldObjectPath,
                    NextAttemptAt = DateTime.UtcNow
                }
                : null;
            if (deletionJob != null) _context.StorageDeletionJobs.Add(deletionJob);

            var revision = new TrackAudioRevision
            {
                Track = track,
                TrackId = track.Id,
                ReviewGroup = group,
                ReviewGroupId = group.Id,
                ActingUserId = group.ConfirmedByUserId!.Value,
                PreviousObjectPath = oldObjectPath,
                ReplacementObjectPath = objectPath,
                PreviousContentSha256 = track.ContentSha256,
                ReplacementContentSha256 = selected.ContentSha256,
                PreviousCodec = track.Codec,
                ReplacementCodec = selected.Codec,
                PreviousContainer = track.Container,
                ReplacementContainer = selected.Container,
                PreviousIsLossless = track.IsLossless,
                ReplacementIsLossless = selected.IsLossless,
                PreviousSampleRateHz = track.SampleRateHz,
                ReplacementSampleRateHz = selected.SampleRateHz,
                PreviousBitDepth = track.BitDepth,
                ReplacementBitDepth = selected.BitDepth,
                PreviousChannels = track.Channels,
                ReplacementChannels = selected.Channels,
                PreviousBitRateKbps = track.BitRateKbps,
                ReplacementBitRateKbps = selected.BitRateKbps,
                PreviousFileSizeBytes = track.FileSizeBytes,
                ReplacementFileSizeBytes = selected.SizeBytes,
                PreviousExactDurationMilliseconds = track.ExactDurationMilliseconds,
                ReplacementExactDurationMilliseconds = selected.ExactDurationMilliseconds,
                PreviousFingerprintVersion = track.FingerprintVersion,
                ReplacementFingerprintVersion = selected.FingerprintVersion,
                PreviousFingerprintAlgorithm = track.FingerprintAlgorithm,
                ReplacementFingerprintAlgorithm = selected.FingerprintAlgorithm,
                PreviousFingerprintPayload = track.FingerprintPayload,
                ReplacementFingerprintPayload = selected.FingerprintPayload,
                PreviousFingerprintFrameCount = track.FingerprintFrameCount,
                ReplacementFingerprintFrameCount = selected.FingerprintFrameCount,
                PreviousFingerprintDurationMilliseconds = track.FingerprintDurationMilliseconds,
                ReplacementFingerprintDurationMilliseconds = selected.FingerprintDurationMilliseconds,
                StorageDeletionJob = deletionJob,
                StorageDeletionJobId = deletionJob?.Id,
                CleanupStatus = deletionJob == null
                    ? TrackAudioRevisionCleanupStatus.NotRequired
                    : TrackAudioRevisionCleanupStatus.Pending
            };
            _context.TrackAudioRevisions.Add(revision);

            track.FilePath = objectPath;
            track.DurationSeconds = checked((int)Math.Round(
                selected.ExactDurationMilliseconds!.Value / 1000d));
            track.BitRate = selected.BitRateKbps ?? 0;
            track.Format = selected.Container ?? selected.Extension.TrimStart('.');
            track.ContentSha256 = selected.ContentSha256;
            track.FileSizeBytes = selected.SizeBytes;
            track.OriginalFileName = selected.OriginalFileName;
            track.Codec = selected.Codec;
            track.Container = selected.Container;
            track.IsLossless = selected.IsLossless;
            track.SampleRateHz = selected.SampleRateHz;
            track.BitDepth = selected.BitDepth;
            track.Channels = selected.Channels;
            track.BitRateKbps = selected.BitRateKbps;
            track.ExactDurationMilliseconds = selected.ExactDurationMilliseconds;
            track.FingerprintVersion = selected.FingerprintVersion;
            track.FingerprintAlgorithm = selected.FingerprintAlgorithm;
            track.FingerprintPayload = selected.FingerprintPayload;
            track.FingerprintFrameCount = selected.FingerprintFrameCount;
            track.FingerprintDurationMilliseconds = selected.FingerprintDurationMilliseconds;

            foreach (var item in group.Items)
            {
                item.TrackId = track.Id;
                item.ObjectPath = ReferenceEquals(item, selected) ? objectPath : null;
                item.Status = ReferenceEquals(item, selected)
                    ? MusicImportItemStatus.Imported
                    : MusicImportItemStatus.Duplicate;
                item.Stage = MusicImportItemStage.Verified;
                item.CompletedAt = DateTime.UtcNow;
                item.Retryable = false;
                item.ErrorCode = null;
                item.ErrorMessage = null;
                if (item.SourceKind == MusicImportSourceKind.BrowserStaging &&
                    item.SourceReference is { } stagingPath &&
                    ImportObjectPath.IsStaging(stagingPath))
                {
                    _deletionQueue.Enqueue(stagingPath);
                }
            }
            group.Status = MusicImportReviewStatus.Applied;
            await _context.SaveChangesAsync(cancellationToken);
            if (transaction != null) await transaction.CommitAsync(cancellationToken);
            return new MusicImportApplyResult(group.Id, track.Id, false);
        }
        catch
        {
            if (transaction != null)
                await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    private async Task CompensateUnlessReferencedAsync(string objectPath)
    {
        _context.ChangeTracker.Clear();
        var referenced = await _context.Tracks
            .AsNoTracking()
            .AnyAsync(track => track.FilePath == objectPath);
        if (!referenced)
            await _deletionQueue.CompensateUploadAsync(_storage, objectPath);
    }

    private async Task<Artist?> GetOrCreateArtistAsync(
        string? name,
        CancellationToken cancellationToken)
    {
        var normalized = name?.Trim();
        if (string.IsNullOrEmpty(normalized)) return null;
        var lowered = normalized.ToLowerInvariant();
        var artist = await _context.Artists.FirstOrDefaultAsync(
            candidate => candidate.Name.ToLower() == lowered,
            cancellationToken);
        if (artist != null) return artist;
        artist = new Artist { Name = normalized };
        _context.Artists.Add(artist);
        return artist;
    }

    private async Task<Album?> GetOrCreateAlbumAsync(
        string? title,
        Artist? artist,
        CancellationToken cancellationToken)
    {
        var normalized = title?.Trim();
        if (string.IsNullOrEmpty(normalized)) return null;
        var lowered = normalized.ToLowerInvariant();
        var artistId = artist?.Id;
        var album = await _context.Albums.FirstOrDefaultAsync(
            candidate => candidate.ArtistId == artistId &&
                candidate.Title.ToLower() == lowered,
            cancellationToken);
        if (album != null) return album;
        album = new Album { Title = normalized, Artist = artist, ArtistId = artistId };
        _context.Albums.Add(album);
        return album;
    }
}
