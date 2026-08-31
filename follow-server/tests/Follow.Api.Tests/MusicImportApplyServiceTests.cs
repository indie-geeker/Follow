using System.Security.Cryptography;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public class MusicImportApplyServiceTests
{
    [Fact]
    public void ConfirmedApply_WritesEmbeddedAssetsThroughManagedWriter()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Infrastructure/Services/MusicImportApplyService.cs"));

        Assert.Contains("EmbeddedTrackAssetWriter", source);
        Assert.Contains("_assetWriter.WriteAsync", source);
        Assert.Contains("CoverUrl", source);
        Assert.Contains("LyricsUrl", source);
    }

    [Fact]
    public async Task CreateTrack_WritesOnlyExplicitSelectionAndLinksRejectedCandidates()
    {
        using var directory = new TemporaryDirectory();
        var first = await WriteSourceAsync(directory.Path, "selected.flac", 7);
        var second = await WriteSourceAsync(directory.Path, "rejected.mp3", 8);
        await using var context = CreateContext();
        var seeded = await SeedCreateGroupAsync(context, first, second);
        var storage = new ApplyRecordingStorage();
        var service = CreateService(context, directory.Path, storage);

        var result = await service.ApplyGroupAsync(seeded.Group.Id, 0);

        var track = await context.Tracks.SingleAsync();
        Assert.Equal(track.Id, result.TrackId);
        Assert.Equal("selected", track.Title);
        Assert.Equal(seeded.Selected.ContentSha256, track.ContentSha256);
        Assert.Equal(seeded.Selected.FingerprintPayload, track.FingerprintPayload);
        Assert.Single(storage.Writes);
        Assert.Equal(
            ImportObjectPath.BuildRevision(
                seeded.Group.Id,
                0,
                seeded.Selected.Id,
                ".flac"),
            track.FilePath);
        Assert.Equal(first.Bytes, storage.Objects[track.FilePath]);
        Assert.All(await context.MusicImportItems.ToListAsync(), item =>
            Assert.Equal(track.Id, item.TrackId));
        Assert.Equal(MusicImportItemStatus.Imported, seeded.Selected.Status);
        Assert.Equal(MusicImportItemStatus.Duplicate, seeded.Rejected.Status);
        Assert.Equal(MusicImportReviewStatus.Applied, seeded.Group.Status);
    }

    [Fact]
    public async Task CreateTrack_PersistsEmbeddedCoverAndTimedLyrics()
    {
        using var directory = new TemporaryDirectory();
        var first = await WriteSourceAsync(directory.Path, "selected.flac", 7);
        var second = await WriteSourceAsync(directory.Path, "rejected.mp3", 8);
        await using var context = CreateContext();
        var seeded = await SeedCreateGroupAsync(context, first, second);
        var storage = new ApplyRecordingStorage();
        var metadata = new RecordingMetadataExtractor(new AudioMetadata(
            "selected",
            "artist",
            "album",
            60,
            900,
            "flac",
            CoverData: [1, 2, 3],
            CoverContentType: "image/png",
            TimedLyrics: "[00:01.20]line"));
        var service = CreateService(
            context,
            directory.Path,
            storage,
            metadata);

        await service.ApplyGroupAsync(seeded.Group.Id, 0);

        var track = await context.Tracks.SingleAsync();
        Assert.Equal(1, metadata.CallCount);
        Assert.Equal($"covers/{track.Id}/cover.png", track.CoverUrl);
        Assert.Equal($"lyrics/{track.Id}/lyrics.lrc", track.LyricsUrl);
        Assert.Equal(3, storage.Writes.Count);
        Assert.True(storage.Objects.ContainsKey(Assert.IsType<string>(track.CoverUrl)));
        Assert.True(storage.Objects.ContainsKey(Assert.IsType<string>(track.LyricsUrl)));
    }

    [Theory]
    [InlineData(MusicImportReviewStatus.Open)]
    [InlineData(MusicImportReviewStatus.Deferred)]
    [InlineData(MusicImportReviewStatus.Confirmed)]
    public async Task CreateTrack_RefusesGroupsThatAreNotLocked(
        MusicImportReviewStatus status)
    {
        using var directory = new TemporaryDirectory();
        var first = await WriteSourceAsync(directory.Path, "selected.flac", 7);
        var second = await WriteSourceAsync(directory.Path, "rejected.mp3", 8);
        await using var context = CreateContext();
        var seeded = await SeedCreateGroupAsync(context, first, second);
        seeded.Group.Status = status;
        await context.SaveChangesAsync();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateService(context, directory.Path, new ApplyRecordingStorage())
                .ApplyGroupAsync(seeded.Group.Id, seeded.Group.Version));
    }

    [Fact]
    public async Task CreateTrack_RevalidatesHashFingerprintAndVersionBeforeWriting()
    {
        using var directory = new TemporaryDirectory();
        var first = await WriteSourceAsync(directory.Path, "selected.flac", 7);
        var second = await WriteSourceAsync(directory.Path, "rejected.mp3", 8);
        await using var context = CreateContext();
        var seeded = await SeedCreateGroupAsync(context, first, second);
        seeded.Selected.ContentSha256 = Enumerable.Repeat((byte)99, 32).ToArray();
        await context.SaveChangesAsync();
        var storage = new ApplyRecordingStorage();
        var service = CreateService(context, directory.Path, storage);

        await Assert.ThrowsAsync<MusicImportApplyValidationException>(() =>
            service.ApplyGroupAsync(seeded.Group.Id, seeded.Group.Version));
        await Assert.ThrowsAsync<MusicImportApplyConflictException>(() =>
            service.ApplyGroupAsync(seeded.Group.Id, seeded.Group.Version + 1));

        Assert.Empty(storage.Writes);
        Assert.Empty(await context.Tracks.ToListAsync());
    }

    [Fact]
    public async Task Apply_RejectsSeparateRecordingsForExactShaGroupBeforeWriting()
    {
        using var directory = new TemporaryDirectory();
        var first = await WriteSourceAsync(directory.Path, "selected.flac", 7);
        var second = await WriteSourceAsync(directory.Path, "rejected.mp3", 8);
        await using var context = CreateContext();
        var seeded = await SeedCreateGroupAsync(context, first, second);
        seeded.Group.MatchKind = MusicImportMatchKind.ExactSha256;
        seeded.Selected.Decision = MusicImportDecisionKind.TreatAsSeparateRecording;
        seeded.Rejected.Decision = MusicImportDecisionKind.TreatAsSeparateRecording;
        await context.SaveChangesAsync();
        var storage = new ApplyRecordingStorage();

        var exception = await Assert.ThrowsAsync<MusicImportApplyValidationException>(() =>
            CreateService(context, directory.Path, storage)
                .ApplyGroupAsync(seeded.Group.Id, seeded.Group.Version));

        Assert.Contains("byte-identical", exception.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Empty(storage.Writes);
        Assert.Empty(await context.Tracks.ToListAsync());
    }

    [Fact]
    public async Task CreateTrack_IsRestartIdempotentAndCompensatesDatabaseFailure()
    {
        using var directory = new TemporaryDirectory();
        var first = await WriteSourceAsync(directory.Path, "selected.flac", 7);
        var second = await WriteSourceAsync(directory.Path, "rejected.mp3", 8);
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase($"apply-failure-{Guid.NewGuid():N}")
            .Options;
        await using var context = new FailNextTrackSaveContext(options);
        var seeded = await SeedCreateGroupAsync(context, first, second);
        var storage = new ApplyRecordingStorage();
        var metadata = new RecordingMetadataExtractor(new AudioMetadata(
            "selected",
            "artist",
            "album",
            60,
            900,
            "flac",
            CoverData: [1, 2, 3],
            CoverContentType: "image/png",
            TimedLyrics: "[00:01.20]line"));
        var service = CreateService(context, directory.Path, storage, metadata);
        context.FailNextTrackSave = true;

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.ApplyGroupAsync(seeded.Group.Id, 0));

        Assert.Equal(3, storage.Deletes.Count);
        Assert.Empty(storage.Objects);
        Assert.Empty(await context.Tracks.ToListAsync());

        context.ChangeTracker.Clear();
        var retryResult = await CreateService(context, directory.Path, storage, metadata)
            .ApplyGroupAsync(seeded.Group.Id, 0);
        var repeated = await CreateService(context, directory.Path, storage, metadata)
            .ApplyGroupAsync(seeded.Group.Id, 1);

        Assert.Equal(retryResult.TrackId, repeated.TrackId);
        Assert.Single(await context.Tracks.ToListAsync());
        Assert.Equal(6, storage.Writes.Count);
    }

    private static MusicImportApplyService CreateService(
        FollowDbContext context,
        string sourceRoot,
        ApplyRecordingStorage storage,
        IAudioMetadataExtractor? metadataExtractor = null) => new(
        context,
        new MusicImportSourceReader(
            MusicImportScannerTests.EnabledSettings(sourceRoot),
            storage),
        new ApplyFingerprintService(),
        metadataExtractor ?? new RecordingMetadataExtractor(new AudioMetadata(
            "Track", null, null, 60, 128, "mp3")),
        storage,
        new EmbeddedTrackAssetWriter(storage),
        new StorageDeletionQueue(context));

    private static FollowDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase($"apply-{Guid.NewGuid():N}")
            .Options);

    private static async Task<SeededCreateGroup> SeedCreateGroupAsync(
        FollowDbContext context,
        SourceFile selected,
        SourceFile rejected)
    {
        var user = new User
        {
            Username = $"admin-{Guid.NewGuid():N}",
            Email = $"{Guid.NewGuid():N}@example.test",
            PasswordHash = "test",
            Role = UserRole.Admin
        };
        var batch = new MusicImportBatch
        {
            RequestedByUser = user,
            RequestedByUserId = user.Id,
            ClientRequestId = Guid.NewGuid().ToString("N"),
            Status = MusicImportBatchStatus.Applying
        };
        var group = new MusicImportReviewGroup
        {
            Batch = batch,
            BatchId = batch.Id,
            Status = MusicImportReviewStatus.Locked,
            ConfirmedByUser = user,
            ConfirmedByUserId = user.Id,
            ConfirmedAt = DateTime.UtcNow
        };
        var selectedItem = Candidate(batch, group, selected, MusicImportDecisionKind.CreateTrack);
        var rejectedItem = Candidate(batch, group, rejected, MusicImportDecisionKind.RejectDuplicate);
        context.AddRange(user, batch, group, selectedItem, rejectedItem);
        await context.SaveChangesAsync();
        return new SeededCreateGroup(group, selectedItem, rejectedItem);
    }

    private static MusicImportItem Candidate(
        MusicImportBatch batch,
        MusicImportReviewGroup group,
        SourceFile source,
        MusicImportDecisionKind decision)
    {
        var frames = Enumerable.Repeat(unchecked((uint)source.Marker), 80).ToArray();
        return new MusicImportItem
        {
            Batch = batch,
            BatchId = batch.Id,
            ReviewGroup = group,
            ReviewGroupId = group.Id,
            SourceKind = MusicImportSourceKind.MountedDirectory,
            SourceReference = source.Name,
            RelativePath = source.Name,
            OriginalFileName = source.Name,
            Extension = Path.GetExtension(source.Name),
            SizeBytes = source.Bytes.LongLength,
            SourceModifiedAt = source.ModifiedAt,
            Stage = MusicImportItemStage.AwaitingReview,
            Decision = decision,
            ExtractedTitle = Path.GetFileNameWithoutExtension(source.Name),
            ExtractedArtist = "artist",
            ExtractedAlbum = "album",
            Codec = source.Name.EndsWith(".flac") ? "flac" : "mp3",
            Container = source.Name.EndsWith(".flac") ? "flac" : "mpeg",
            IsLossless = source.Name.EndsWith(".flac"),
            SampleRateHz = 44_100,
            BitDepth = source.Name.EndsWith(".flac") ? 16 : null,
            Channels = 2,
            BitRateKbps = source.Name.EndsWith(".flac") ? 900 : 320,
            ExactDurationMilliseconds = 60_000,
            ContentSha256 = SHA256.HashData(source.Bytes),
            FingerprintVersion = "1.6.1",
            FingerprintAlgorithm = 2,
            FingerprintPayload = AudioFingerprintPayloadCodec.Encode(frames),
            FingerprintFrameCount = frames.Length,
            FingerprintDurationMilliseconds = 60_000
        };
    }

    private static async Task<SourceFile> WriteSourceAsync(
        string root,
        string name,
        byte marker)
    {
        var bytes = Enumerable.Repeat(marker, 1024).ToArray();
        var path = Path.Combine(root, name);
        await File.WriteAllBytesAsync(path, bytes);
        return new SourceFile(
            name,
            bytes,
            marker,
            MusicImportScanner.NormalizeDatabaseTimestamp(File.GetLastWriteTimeUtc(path)));
    }

    private sealed record SourceFile(
        string Name,
        byte[] Bytes,
        byte Marker,
        DateTime ModifiedAt);

    private sealed record SeededCreateGroup(
        MusicImportReviewGroup Group,
        MusicImportItem Selected,
        MusicImportItem Rejected);

    private sealed class ApplyFingerprintService : IAudioFingerprintService
    {
        public Task<AudioFingerprintCapability> CheckCapabilityAsync(CancellationToken cancellationToken = default) =>
            Task.FromResult(new AudioFingerprintCapability(true, "1.6.1", 2, null, null));

        public Task<AudioFingerprint> ExtractAsync(
            Stream source,
            TimeSpan sourceDuration,
            CancellationToken cancellationToken = default)
        {
            var marker = source.ReadByte();
            return Task.FromResult(new AudioFingerprint(
                2,
                "1.6.1",
                sourceDuration,
                Enumerable.Repeat(unchecked((uint)marker), 80).ToArray()));
        }
    }

    private sealed class ApplyRecordingStorage : IStorageService
    {
        public Dictionary<string, byte[]> Objects { get; } = new(StringComparer.Ordinal);
        public List<string> Writes { get; } = [];
        public List<string> Deletes { get; } = [];

        public async Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default)
        {
            using var buffer = new MemoryStream();
            await source.CopyToAsync(buffer, cancellationToken);
            if (buffer.Length != length) throw new EndOfStreamException();
            Objects[objectPath] = buffer.ToArray();
            Writes.Add(objectPath);
        }

        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) =>
            Task.FromResult(Objects.TryGetValue(filePath, out var bytes)
                ? new StorageObjectMetadata(bytes.LongLength, "audio/mpeg", Convert.ToHexString(SHA256.HashData(bytes)))
                : null);

        public async Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default)
        {
            var bytes = Objects[filePath];
            await destination.WriteAsync(bytes.AsMemory((int)offset, (int)length), cancellationToken);
        }

        public Task<bool> DeleteFileAsync(string filePath)
        {
            Deletes.Add(filePath);
            return Task.FromResult(Objects.Remove(filePath));
        }

        public async Task<string> UploadFileAsync(
            Stream fileStream,
            string fileName,
            string contentType,
            string? folder = null)
        {
            var objectPath = $"{folder}/{fileName}";
            using var buffer = new MemoryStream();
            await fileStream.CopyToAsync(buffer);
            Objects[objectPath] = buffer.ToArray();
            Writes.Add(objectPath);
            return objectPath;
        }
    }
}
