using System.Security.Cryptography;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public class MusicImportReplacementTests
{
    [Fact]
    public async Task Replacement_PreservesTrackIdentityRelationshipsAndAuditsRevision()
    {
        using var directory = new TemporaryDirectory();
        var sourceBytes = Enumerable.Repeat((byte)9, 512).ToArray();
        var sourceName = "replacement.flac";
        var sourcePath = Path.Combine(directory.Path, sourceName);
        await File.WriteAllBytesAsync(sourcePath, sourceBytes);
        var modifiedAt = MusicImportScanner.NormalizeDatabaseTimestamp(
            File.GetLastWriteTimeUtc(sourcePath));
        await using var context = CreateContext();
        var seeded = await SeedAsync(context, sourceName, sourceBytes, modifiedAt);
        var storage = new ReplacementStorage(new Dictionary<string, byte[]>
        {
            [seeded.OldObjectPath] = [1, 2, 3]
        });
        var service = new MusicImportApplyService(
            context,
            new MusicImportSourceReader(
                MusicImportScannerTests.EnabledSettings(directory.Path),
                storage),
            new ReplacementFingerprintService(),
            storage,
            new StorageDeletionQueue(context));

        var result = await service.ApplyGroupAsync(seeded.GroupId, 0);

        context.ChangeTracker.Clear();
        var track = await context.Tracks.SingleAsync();
        Assert.Equal(seeded.TrackId, result.TrackId);
        Assert.Equal(seeded.TrackId, track.Id);
        Assert.NotEqual(seeded.OldObjectPath, track.FilePath);
        Assert.Equal(sourceBytes, storage.Objects[track.FilePath]);
        Assert.True(storage.Objects.ContainsKey(seeded.OldObjectPath));
        Assert.Equal(1, await context.PlaylistTracks.CountAsync(item => item.TrackId == track.Id));
        Assert.Equal(1, await context.Favorites.CountAsync(item => item.TrackId == track.Id));
        Assert.Equal(1, await context.PlayHistories.CountAsync(item => item.TrackId == track.Id));
        Assert.Equal(1, await context.TrackTags.CountAsync(item => item.TrackId == track.Id));
        var revision = await context.TrackAudioRevisions.SingleAsync();
        Assert.Equal(seeded.OldObjectPath, revision.PreviousObjectPath);
        Assert.Equal(track.FilePath, revision.ReplacementObjectPath);
        Assert.Equal(TrackAudioRevisionCleanupStatus.Pending, revision.CleanupStatus);
        Assert.Equal(
            seeded.OldObjectPath,
            (await context.StorageDeletionJobs.SingleAsync()).ObjectPath);

        var repeated = await new MusicImportApplyService(
                context,
                new MusicImportSourceReader(
                    MusicImportScannerTests.EnabledSettings(directory.Path),
                    storage),
                new ReplacementFingerprintService(),
                storage,
                new StorageDeletionQueue(context))
            .ApplyGroupAsync(seeded.GroupId, 1);
        Assert.True(repeated.AlreadyApplied);
        Assert.Single(await context.TrackAudioRevisions.ToListAsync());
    }

    private static FollowDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase($"replacement-{Guid.NewGuid():N}")
            .Options);

    private static async Task<SeededReplacement> SeedAsync(
        FollowDbContext context,
        string sourceName,
        byte[] sourceBytes,
        DateTime modifiedAt)
    {
        var user = new User
        {
            Username = "replacement-admin",
            Email = "replacement@example.test",
            PasswordHash = "test",
            Role = UserRole.Admin
        };
        var oldObjectPath = "tracks/original/audio.mp3";
        var track = new Track
        {
            Title = "old title",
            FilePath = oldObjectPath,
            ContentSha256 = SHA256.HashData([1, 2, 3]),
            FileSizeBytes = 3,
            OriginalFileName = "old.mp3",
            Codec = "mp3",
            Container = "mpeg",
            BitRateKbps = 128,
            ExactDurationMilliseconds = 60_000
        };
        var playlist = new Playlist
        {
            Name = "preserved",
            User = user,
            UserId = user.Id
        };
        var tag = new Tag { Name = "preserved" };
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
            ExistingTrack = track,
            ExistingTrackId = track.Id,
            ConfirmedByUser = user,
            ConfirmedByUserId = user.Id,
            ConfirmedAt = DateTime.UtcNow
        };
        var frames = Enumerable.Repeat(9u, 80).ToArray();
        var item = new MusicImportItem
        {
            Batch = batch,
            BatchId = batch.Id,
            ReviewGroup = group,
            ReviewGroupId = group.Id,
            SourceKind = MusicImportSourceKind.MountedDirectory,
            SourceReference = sourceName,
            RelativePath = sourceName,
            OriginalFileName = sourceName,
            Extension = ".flac",
            SizeBytes = sourceBytes.LongLength,
            SourceModifiedAt = modifiedAt,
            Stage = MusicImportItemStage.AwaitingReview,
            Decision = MusicImportDecisionKind.ReplaceExistingTrack,
            DecisionTrackId = track.Id,
            ExtractedTitle = "new title",
            ExtractedArtist = "new artist",
            ExtractedAlbum = "new album",
            Codec = "flac",
            Container = "flac",
            IsLossless = true,
            SampleRateHz = 96_000,
            BitDepth = 24,
            Channels = 2,
            BitRateKbps = 2_000,
            ExactDurationMilliseconds = 60_000,
            ContentSha256 = SHA256.HashData(sourceBytes),
            FingerprintVersion = "1.6.1",
            FingerprintAlgorithm = 2,
            FingerprintPayload = AudioFingerprintPayloadCodec.Encode(frames),
            FingerprintFrameCount = frames.Length,
            FingerprintDurationMilliseconds = 60_000
        };
        context.AddRange(
            user,
            track,
            playlist,
            tag,
            batch,
            group,
            item,
            new PlaylistTrack { Playlist = playlist, PlaylistId = playlist.Id, Track = track, TrackId = track.Id },
            new Favorite { User = user, UserId = user.Id, Track = track, TrackId = track.Id },
            new PlayHistory { User = user, UserId = user.Id, Track = track, TrackId = track.Id },
            new TrackTag { Tag = tag, TagId = tag.Id, Track = track, TrackId = track.Id });
        await context.SaveChangesAsync();
        return new SeededReplacement(group.Id, track.Id, oldObjectPath);
    }

    private sealed record SeededReplacement(Guid GroupId, Guid TrackId, string OldObjectPath);

    private sealed class ReplacementFingerprintService : IAudioFingerprintService
    {
        public Task<AudioFingerprintCapability> CheckCapabilityAsync(CancellationToken cancellationToken = default) =>
            Task.FromResult(new AudioFingerprintCapability(true, "1.6.1", 2, null, null));

        public Task<AudioFingerprint> ExtractAsync(Stream source, TimeSpan sourceDuration, CancellationToken cancellationToken = default)
        {
            var marker = source.ReadByte();
            return Task.FromResult(new AudioFingerprint(
                2,
                "1.6.1",
                sourceDuration,
                Enumerable.Repeat(unchecked((uint)marker), 80).ToArray()));
        }
    }

    private sealed class ReplacementStorage(Dictionary<string, byte[]> objects) : IStorageService
    {
        public Dictionary<string, byte[]> Objects { get; } = objects;

        public async Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default)
        {
            using var buffer = new MemoryStream();
            await source.CopyToAsync(buffer, cancellationToken);
            Objects[objectPath] = buffer.ToArray();
        }

        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) =>
            Task.FromResult(Objects.TryGetValue(filePath, out var bytes)
                ? new StorageObjectMetadata(bytes.LongLength, "audio/flac", null)
                : null);

        public async Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) =>
            await destination.WriteAsync(Objects[filePath].AsMemory((int)offset, (int)length), cancellationToken);

        public Task<bool> DeleteFileAsync(string filePath) => Task.FromResult(Objects.Remove(filePath));
        public Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null) => throw new NotSupportedException();
    }
}
