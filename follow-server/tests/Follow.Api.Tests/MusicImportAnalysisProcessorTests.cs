using System.Security.Cryptography;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public class MusicImportAnalysisProcessorTests
{
    private const string LeaseOwner = "analysis-worker";

    [Fact]
    public async Task Analyze_PersistsSnapshotHashMetadataQualityAndFingerprintWithoutTrackOrObject()
    {
        await using var context = CreateContext();
        var bytes = new byte[] { 1, 2, 3, 4 };
        var item = await SeedClaimedItemAsync(context, bytes.Length);
        var snapshot = Snapshot(item);
        var reader = new AnalysisSourceReader(bytes, snapshot);
        var metadata = new RecordingMetadataExtractor(new AudioMetadata(
            "Analyzed title", "Artist", "Album", 12, 320, "flac",
            Codec: "flac", Container: "flac", IsLossless: true,
            SampleRateHz: 96_000, BitDepth: 24, Channels: 2,
            BitRateKbps: 1_200, ExactDurationMilliseconds: 12_345));
        var fingerprint = new AnalysisFingerprintService(
            new AudioFingerprint(2, "1.6.1", TimeSpan.FromMilliseconds(12_345), [1, 2, 3]));
        var processor = new MusicImportAnalysisProcessor(context, reader, metadata, fingerprint);

        await processor.AnalyzeAsync(item.Id, LeaseOwner);

        var persisted = await context.MusicImportItems.AsNoTracking().SingleAsync();
        Assert.Equal(MusicImportItemStatus.Pending, persisted.Status);
        Assert.Equal(MusicImportItemStage.Analyzed, persisted.Stage);
        Assert.Equal(SHA256.HashData(bytes), persisted.ContentSha256);
        Assert.Equal("Analyzed title", persisted.ExtractedTitle);
        Assert.Equal("Artist", persisted.ExtractedArtist);
        Assert.Equal("Album", persisted.ExtractedAlbum);
        Assert.Equal("flac", persisted.Codec);
        Assert.True(persisted.IsLossless);
        Assert.Equal(96_000, persisted.SampleRateHz);
        Assert.Equal(24, persisted.BitDepth);
        Assert.Equal(12_345, persisted.ExactDurationMilliseconds);
        Assert.Equal("1.6.1", persisted.FingerprintVersion);
        Assert.Equal(2, persisted.FingerprintAlgorithm);
        Assert.Equal(3, persisted.FingerprintFrameCount);
        Assert.Equal([1u, 2u, 3u], AudioFingerprintPayloadCodec.Decode(
            persisted.FingerprintPayload!, persisted.FingerprintFrameCount!.Value));
        Assert.Equal(12_345, persisted.FingerprintDurationMilliseconds);
        Assert.Null(persisted.ObjectPath);
        Assert.Null(persisted.TrackId);
        Assert.Null(persisted.LeaseOwner);
        Assert.Empty(await context.Tracks.ToListAsync());
        Assert.Equal(1, reader.OpenCount);
        Assert.Equal(1, metadata.CallCount);
        Assert.Equal(1, fingerprint.ExtractCount);
    }

    [Fact]
    public async Task Analyze_RestartSkipsAlreadyAnalyzedSafeUnit()
    {
        await using var context = CreateContext();
        var item = await SeedClaimedItemAsync(context, 4);
        item.Stage = MusicImportItemStage.Analyzed;
        item.Status = MusicImportItemStatus.Pending;
        item.LeaseOwner = null;
        item.LeaseExpiresAt = null;
        item.ContentSha256 = new byte[32];
        item.FingerprintVersion = "1.6.1";
        item.FingerprintAlgorithm = 2;
        item.FingerprintPayload = AudioFingerprintPayloadCodec.Encode([1]);
        item.FingerprintFrameCount = 1;
        await context.SaveChangesAsync();
        var reader = new AnalysisSourceReader([1, 2, 3, 4], Snapshot(item));
        var metadata = new RecordingMetadataExtractor(new AudioMetadata("unused", null, null, 1, 1, "mp3"));
        var fingerprint = new AnalysisFingerprintService(
            new AudioFingerprint(2, "1.6.1", TimeSpan.FromSeconds(1), [1]));
        var processor = new MusicImportAnalysisProcessor(context, reader, metadata, fingerprint);

        await processor.AnalyzeAsync(item.Id, LeaseOwner);

        Assert.Equal(0, reader.OpenCount);
        Assert.Equal(0, metadata.CallCount);
        Assert.Equal(0, fingerprint.ExtractCount);
        Assert.Empty(await context.Tracks.ToListAsync());
    }

    private static MusicImportSourceSnapshot Snapshot(MusicImportItem item) => new(
        item.SourceKind,
        item.SourceReference!,
        item.SizeBytes,
        item.SourceModifiedAt,
        item.SourceETag);

    private static async Task<MusicImportItem> SeedClaimedItemAsync(
        FollowDbContext context,
        long length)
    {
        var modified = MusicImportScanner.NormalizeDatabaseTimestamp(DateTime.UtcNow);
        var batch = new MusicImportBatch
        {
            RequestedByUserId = Guid.NewGuid(),
            ClientRequestId = Guid.NewGuid().ToString("N"),
            Status = MusicImportBatchStatus.Analyzing
        };
        var item = new MusicImportItem
        {
            Batch = batch,
            BatchId = batch.Id,
            SourceKind = MusicImportSourceKind.MountedDirectory,
            SourceReference = "album/song.flac",
            RelativePath = "album/song.flac",
            OriginalFileName = "song.flac",
            Extension = ".flac",
            SizeBytes = length,
            SourceModifiedAt = modified,
            Status = MusicImportItemStatus.Processing,
            LeaseOwner = LeaseOwner,
            LeaseExpiresAt = DateTime.UtcNow.AddMinutes(5)
        };
        context.AddRange(batch, item);
        await context.SaveChangesAsync();
        return item;
    }

    private static FollowDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);
}

internal sealed class AnalysisSourceReader : IMusicImportSourceReader
{
    private readonly byte[] _content;
    private readonly MusicImportSourceSnapshot _snapshot;

    public AnalysisSourceReader(byte[] content, MusicImportSourceSnapshot snapshot)
    {
        _content = content;
        _snapshot = snapshot;
    }

    public int OpenCount { get; private set; }

    public Task<MusicImportSourceReadHandle> OpenReadAsync(
        MusicImportSourceSnapshot expectedSnapshot,
        CancellationToken cancellationToken = default)
    {
        OpenCount++;
        Assert.Equal(_snapshot, expectedSnapshot);
        return Task.FromResult(new MusicImportSourceReadHandle(
            new MemoryStream(_content, writable: false),
            _snapshot));
    }
}

internal sealed class AnalysisFingerprintService : IAudioFingerprintService
{
    private readonly AudioFingerprint _fingerprint;

    public AnalysisFingerprintService(AudioFingerprint fingerprint) => _fingerprint = fingerprint;
    public int ExtractCount { get; private set; }

    public Task<AudioFingerprintCapability> CheckCapabilityAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult(new AudioFingerprintCapability(true, "1.6.1", 2, null, null));

    public Task<AudioFingerprint> ExtractAsync(
        Stream source,
        TimeSpan sourceDuration,
        CancellationToken cancellationToken = default)
    {
        ExtractCount++;
        Assert.Equal(TimeSpan.FromMilliseconds(12_345), sourceDuration);
        return Task.FromResult(_fingerprint);
    }
}
