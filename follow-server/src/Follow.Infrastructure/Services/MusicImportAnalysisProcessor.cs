using System.Security.Cryptography;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Services;

/// <summary>
/// Performs read-only source analysis. It deliberately has no storage-write or Track service dependency.
/// </summary>
public sealed class MusicImportAnalysisProcessor
{
    private readonly FollowDbContext _context;
    private readonly IMusicImportSourceReader _sourceReader;
    private readonly IAudioMetadataExtractor _metadataExtractor;
    private readonly IAudioFingerprintService _fingerprintService;

    public MusicImportAnalysisProcessor(
        FollowDbContext context,
        IMusicImportSourceReader sourceReader,
        IAudioMetadataExtractor metadataExtractor,
        IAudioFingerprintService fingerprintService)
    {
        _context = context;
        _sourceReader = sourceReader;
        _metadataExtractor = metadataExtractor;
        _fingerprintService = fingerprintService;
    }

    public async Task AnalyzeAsync(
        Guid itemId,
        string leaseOwner,
        CancellationToken cancellationToken = default)
    {
        var item = await _context.MusicImportItems
            .SingleOrDefaultAsync(candidate => candidate.Id == itemId, cancellationToken)
            ?? throw new KeyNotFoundException("Music import item was not found.");
        if (item.Stage is MusicImportItemStage.Analyzed or
            MusicImportItemStage.Grouped or
            MusicImportItemStage.AwaitingReview)
        {
            return;
        }
        ValidateClaim(item, leaseOwner);

        try
        {
            item.Stage = MusicImportItemStage.SourceValidation;
            await _context.SaveChangesAsync(cancellationToken);

            var expectedSnapshot = BuildSnapshot(item);
            await using var source = await _sourceReader.OpenReadAsync(
                expectedSnapshot,
                cancellationToken);
            if (!source.Stream.CanSeek)
                throw new InvalidOperationException("Music import analysis requires a seekable bounded source.");

            item.Stage = MusicImportItemStage.Hashing;
            await _context.SaveChangesAsync(cancellationToken);
            source.Stream.Position = 0;
            item.ContentSha256 = await SHA256.HashDataAsync(source.Stream, cancellationToken);

            item.Stage = MusicImportItemStage.Metadata;
            await _context.SaveChangesAsync(cancellationToken);
            source.Stream.Position = 0;
            var metadata = await _metadataExtractor.ExtractAsync(
                source.Stream,
                item.OriginalFileName,
                cancellationToken);
            ValidateMetadata(metadata);
            PersistMetadata(item, metadata);

            item.Stage = MusicImportItemStage.Fingerprinting;
            await _context.SaveChangesAsync(cancellationToken);
            source.Stream.Position = 0;
            var exactDuration = TimeSpan.FromMilliseconds(
                metadata.ExactDurationMilliseconds ?? checked(metadata.DurationSeconds * 1000L));
            var fingerprint = await _fingerprintService.ExtractAsync(
                source.Stream,
                exactDuration,
                cancellationToken);
            if (fingerprint.Frames.Count == 0)
                throw new InvalidDataException("Fingerprint extraction returned no frames.");
            item.FingerprintVersion = fingerprint.Version;
            item.FingerprintAlgorithm = fingerprint.Algorithm;
            item.FingerprintPayload = AudioFingerprintPayloadCodec.Encode(fingerprint.Frames);
            item.FingerprintFrameCount = fingerprint.Frames.Count;
            item.FingerprintDurationMilliseconds = checked((long)Math.Round(
                fingerprint.SourceDuration.TotalMilliseconds));

            item.Stage = MusicImportItemStage.Analyzed;
            item.Status = MusicImportItemStatus.Pending;
            item.Retryable = false;
            item.LeaseOwner = null;
            item.LeaseExpiresAt = null;
            item.ErrorCode = null;
            item.ErrorMessage = null;
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            item.Status = MusicImportItemStatus.Failed;
            item.Retryable = exception is not MusicImportSourceChangedException and not ArgumentException;
            item.LeaseOwner = null;
            item.LeaseExpiresAt = null;
            item.ErrorCode = exception is MusicImportSourceChangedException
                ? "SOURCE_CHANGED"
                : exception is AudioFingerprintExtractionException
                    ? "FINGERPRINT_ERROR"
                    : "ANALYSIS_ERROR";
            item.ErrorMessage = "Music source analysis failed.";
            item.CompletedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(CancellationToken.None);
        }
    }

    private static MusicImportSourceSnapshot BuildSnapshot(MusicImportItem item)
    {
        var reference = item.SourceReference ?? item.RelativePath;
        return new MusicImportSourceSnapshot(
            item.SourceKind,
            reference,
            item.SizeBytes,
            item.SourceKind == MusicImportSourceKind.MountedDirectory
                ? item.SourceModifiedAt
                : null,
            item.SourceETag);
    }

    private static void ValidateClaim(MusicImportItem item, string leaseOwner)
    {
        if (item.Status != MusicImportItemStatus.Processing ||
            !string.Equals(item.LeaseOwner, leaseOwner, StringComparison.Ordinal) ||
            item.LeaseExpiresAt is not DateTime expiry ||
            expiry <= DateTime.UtcNow)
        {
            throw new InvalidOperationException("The music import analysis lease is not owned by this worker.");
        }
    }

    private static void ValidateMetadata(AudioMetadata metadata)
    {
        if (string.IsNullOrWhiteSpace(metadata.Title) ||
            metadata.DurationSeconds <= 0 ||
            metadata.ExactDurationMilliseconds is long exactDuration && exactDuration <= 0)
        {
            throw new ArgumentException("Audio metadata is incomplete.", nameof(metadata));
        }
    }

    private static void PersistMetadata(MusicImportItem item, AudioMetadata metadata)
    {
        item.ExtractedTitle = metadata.Title.Trim();
        item.ExtractedArtist = NullIfWhiteSpace(metadata.Artist);
        item.ExtractedAlbum = NullIfWhiteSpace(metadata.Album);
        item.Codec = NullIfWhiteSpace(metadata.Codec) ?? NullIfWhiteSpace(metadata.Format);
        item.Container = NullIfWhiteSpace(metadata.Container) ?? NullIfWhiteSpace(metadata.Format);
        item.IsLossless = metadata.IsLossless;
        item.SampleRateHz = metadata.SampleRateHz;
        item.BitDepth = metadata.BitDepth;
        item.Channels = metadata.Channels;
        item.BitRateKbps = metadata.BitRateKbps ?? (metadata.BitRate > 0 ? metadata.BitRate : null);
        item.ExactDurationMilliseconds = metadata.ExactDurationMilliseconds ??
            checked(metadata.DurationSeconds * 1000L);
    }

    private static string? NullIfWhiteSpace(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
