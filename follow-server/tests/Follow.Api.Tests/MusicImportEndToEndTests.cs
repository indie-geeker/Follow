using System.Security.Cryptography;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Options;
using Follow.Infrastructure.Services;
using Follow.Api.Tests.Infrastructure;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Follow.Api.Tests;

public sealed class MusicImportEndToEndTests
{
    [Fact]
    public async Task DisposablePostgres_AnalysisAndGroupingCreateReviewOnlyAndNoTrack()
    {
        await using var stack = await DisposableMusicImportStack.CreateAsync();
        var bytes = Enumerable.Repeat((byte)51, 1024).ToArray();
        await File.WriteAllBytesAsync(Path.Combine(stack.SourceDirectory, "same-a.flac"), bytes);
        await File.WriteAllBytesAsync(Path.Combine(stack.SourceDirectory, "same-b.mp3"), bytes);
        stack.SealSourceDirectoryReadOnly();

        await using var context = stack.CreateContext();
        var user = Admin();
        var batch = new MusicImportBatch
        {
            RequestedByUser = user,
            RequestedByUserId = user.Id,
            ClientRequestId = Guid.NewGuid().ToString("N"),
            SourceKind = MusicImportSourceKind.MountedDirectory,
            Status = MusicImportBatchStatus.Analyzing
        };
        var leaseOwner = "restartable-analysis";
        foreach (var name in new[] { "same-a.flac", "same-b.mp3" })
        {
            var path = Path.Combine(stack.SourceDirectory, name);
            batch.Items.Add(new MusicImportItem
            {
                Batch = batch,
                BatchId = batch.Id,
                SourceKind = MusicImportSourceKind.MountedDirectory,
                SourceReference = name,
                RelativePath = name,
                OriginalFileName = name,
                Extension = Path.GetExtension(name),
                SizeBytes = bytes.LongLength,
                SourceModifiedAt = MusicImportScanner.NormalizeDatabaseTimestamp(File.GetLastWriteTimeUtc(path)),
                Status = MusicImportItemStatus.Processing,
                Stage = MusicImportItemStage.None,
                LeaseOwner = leaseOwner,
                LeaseExpiresAt = DateTime.UtcNow.AddMinutes(5)
            });
        }
        context.AddRange(user, batch);
        await context.SaveChangesAsync();
        var sourceReader = new MusicImportSourceReader(
            new MusicImportRuntimeSettings
            {
                Enabled = true,
                SourceRoot = stack.SourceDirectory,
                MaximumFileBytes = 10_000
            },
            stack.Storage);
        var metadata = new RecordingMetadataExtractor(new AudioMetadata(
            "generated",
            "artist",
            "album",
            60,
            320,
            "mpeg",
            Codec: "mp3",
            Container: "mpeg",
            IsLossless: false,
            SampleRateHz: 44_100,
            Channels: 2,
            BitRateKbps: 320,
            ExactDurationMilliseconds: 60_000));
        var analyzer = new MusicImportAnalysisProcessor(
            context,
            sourceReader,
            metadata,
            new MarkerFingerprintService());

        foreach (var itemId in batch.Items.Select(item => item.Id).ToArray())
            await analyzer.AnalyzeAsync(itemId, leaseOwner);
        batch.Status = MusicImportBatchStatus.Grouping;
        await context.SaveChangesAsync();
        await new MusicImportGroupingService(
            context,
            Options.Create(new AudioFingerprintOptions())).GroupBatchAsync(batch.Id);

        Assert.Empty(await context.Tracks.ToListAsync());
        var group = await context.MusicImportReviewGroups.SingleAsync();
        Assert.Equal(MusicImportMatchKind.ExactSha256, group.MatchKind);
        Assert.Null(group.ConfirmedByUserId);
        Assert.All(await context.MusicImportItems.ToListAsync(), item => Assert.Null(item.Decision));
    }

    [Fact]
    public async Task DisposablePostgresAndMinio_ExplicitNonRecommendedSelectionWinsAndRestartsIdempotently()
    {
        await using var stack = await DisposableMusicImportStack.CreateAsync();
        var recommended = await WriteSourceAsync(stack.SourceDirectory, "recommended.flac", 61);
        var selected = await WriteSourceAsync(stack.SourceDirectory, "selected.mp3", 62);
        stack.SealSourceDirectoryReadOnly();
        Guid groupId;
        Guid selectedItemId;
        await using (var seed = stack.CreateContext())
        {
            var seeded = await SeedCreateGroupAsync(seed, recommended, selected);
            seeded.Group.RecommendedItemId = seeded.Rejected.Id;
            seeded.Selected.Decision = MusicImportDecisionKind.RejectDuplicate;
            seeded.Rejected.Decision = MusicImportDecisionKind.CreateTrack;
            await seed.SaveChangesAsync();
            groupId = seeded.Group.Id;
            selectedItemId = seeded.Rejected.Id;
        }

        await using (var apply = stack.CreateContext())
        {
            await CreateService(apply, stack.SourceDirectory, stack.Storage)
                .ApplyGroupAsync(groupId, 1);
        }
        await using (var restart = stack.CreateContext())
        {
            var repeated = await CreateService(restart, stack.SourceDirectory, stack.Storage)
                .ApplyGroupAsync(groupId, 2);
            Assert.True(repeated.AlreadyApplied);
        }

        await using var verify = stack.CreateContext();
        var track = await verify.Tracks.SingleAsync();
        Assert.Equal("selected", track.Title);
        Assert.Equal(selectedItemId, (await verify.MusicImportItems
            .SingleAsync(item => item.Status == MusicImportItemStatus.Imported)).Id);
        await using var range = new MemoryStream();
        await stack.Storage.CopyRangeToAsync(track.FilePath, 10, 20, range);
        Assert.Equal(selected.Bytes.AsSpan(10, 20).ToArray(), range.ToArray());
        Assert.Single(stack.Storage.WrittenObjectPaths);
    }

    [Theory]
    [InlineData(MusicImportDecisionKind.KeepExistingTrack)]
    [InlineData(MusicImportDecisionKind.RejectDuplicate)]
    public async Task ExistingTrackDecision_AppliesWithoutWritingNewTrackAndQueuesStagingCleanup(
        MusicImportDecisionKind decision)
    {
        await using var context = CreateContext();
        var storage = new RecordingStorage();
        var seeded = await SeedExistingTrackGroupAsync(context, storage, decision);
        var service = CreateService(context, sourceRoot: string.Empty, storage);

        var result = await service.ApplyGroupAsync(seeded.Group.Id, 0);

        Assert.Equal(seeded.Track.Id, result.TrackId);
        Assert.Empty(storage.Writes);
        Assert.Single(await context.Tracks.ToListAsync());
        Assert.Equal(MusicImportReviewStatus.Applied, seeded.Group.Status);
        Assert.All(seeded.Group.Items, item =>
        {
            Assert.Equal(seeded.Track.Id, item.TrackId);
            Assert.Equal(MusicImportItemStatus.Duplicate, item.Status);
            Assert.Equal(MusicImportItemStage.Verified, item.Stage);
        });
        Assert.Equal(2, await context.StorageDeletionJobs.CountAsync());
    }

    [Fact]
    public async Task TreatAsSeparateRecording_CreatesOneTrackPerExplicitCandidateAndIsRestartIdempotent()
    {
        await using var stack = await DisposableMusicImportStack.CreateAsync();
        var first = await WriteSourceAsync(stack.SourceDirectory, "variant-a.flac", 31);
        var second = await WriteSourceAsync(stack.SourceDirectory, "variant-b.mp3", 32);
        stack.SealSourceDirectoryReadOnly();
        Guid groupId;
        await using (var seed = stack.CreateContext())
        {
            groupId = (await SeedSeparateGroupAsync(seed, first, second)).Id;
        }
        await using (var apply = stack.CreateContext())
        {
            await CreateService(apply, stack.SourceDirectory, stack.Storage).ApplyGroupAsync(groupId, 0);
        }
        await using (var restart = stack.CreateContext())
        {
            await CreateService(restart, stack.SourceDirectory, stack.Storage).ApplyGroupAsync(groupId, 1);
        }

        await using var context = stack.CreateContext();
        var tracks = await context.Tracks.OrderBy(track => track.Title).ToListAsync();
        var items = await context.MusicImportItems.OrderBy(item => item.OriginalFileName).ToListAsync();
        Assert.Equal(2, tracks.Count);
        Assert.Equal(2, stack.Storage.WrittenObjectPaths.Count);
        Assert.Equal(2, items.Select(item => item.TrackId).Distinct().Count());
        Assert.All(items, item => Assert.Equal(MusicImportItemStatus.Imported, item.Status));
        Assert.Equal(
            MusicImportMatchKind.UserSeparated,
            (await context.MusicImportReviewGroups.SingleAsync()).MatchKind);
    }

    [Fact]
    public async Task DisposablePostgresAndMinio_PartialSuccessRetryCanReviewAndApplyNewGroup()
    {
        await using var stack = await DisposableMusicImportStack.CreateAsync();
        var alreadyApplied = await WriteSourceAsync(stack.SourceDirectory, "already.flac", 71);
        var retrySource = await WriteSourceAsync(stack.SourceDirectory, "retry.flac", 72);
        stack.SealSourceDirectoryReadOnly();
        await using var context = stack.CreateContext();
        var user = Admin();
        var existingTrack = new Track
        {
            Title = "already",
            FilePath = "tracks/import/already.flac",
            ContentSha256 = SHA256.HashData(alreadyApplied.Bytes)
        };
        var batch = new MusicImportBatch
        {
            RequestedByUser = user,
            RequestedByUserId = user.Id,
            ClientRequestId = Guid.NewGuid().ToString("N"),
            SourceKind = MusicImportSourceKind.MountedDirectory,
            Status = MusicImportBatchStatus.CompletedWithErrors,
            CompletedAt = DateTime.UtcNow
        };
        var appliedGroup = new MusicImportReviewGroup
        {
            Batch = batch,
            BatchId = batch.Id,
            Status = MusicImportReviewStatus.Applied,
            ConfirmedByUser = user,
            ConfirmedByUserId = user.Id,
            ConfirmedAt = DateTime.UtcNow
        };
        var appliedItem = Candidate(
            batch,
            appliedGroup,
            alreadyApplied,
            MusicImportDecisionKind.CreateTrack);
        appliedItem.Track = existingTrack;
        appliedItem.TrackId = existingTrack.Id;
        appliedItem.Status = MusicImportItemStatus.Imported;
        appliedItem.Stage = MusicImportItemStage.Verified;
        var retryItem = new MusicImportItem
        {
            Batch = batch,
            BatchId = batch.Id,
            SourceKind = MusicImportSourceKind.MountedDirectory,
            SourceReference = retrySource.Name,
            RelativePath = retrySource.Name,
            OriginalFileName = retrySource.Name,
            Extension = ".flac",
            SizeBytes = retrySource.Bytes.LongLength,
            SourceModifiedAt = retrySource.ModifiedAt,
            Status = MusicImportItemStatus.Failed,
            Stage = MusicImportItemStage.Fingerprinting,
            Retryable = true,
            ErrorCode = "FINGERPRINT_ERROR",
            ErrorMessage = "temporary"
        };
        context.AddRange(user, existingTrack, batch, appliedGroup, appliedItem, retryItem);
        await context.SaveChangesAsync();

        var settings = new MusicImportRuntimeSettings
        {
            Enabled = true,
            SourceRoot = stack.SourceDirectory,
            MaximumFileBytes = 10_000
        };
        var ingestion = new MusicImportService(context, settings, stack.Storage);
        Assert.Equal("ready", (await ingestion.RetryFailuresAsync(batch.Id))!.Status);
        Assert.Equal("analyzing", (await ingestion.StartAsync(batch.Id))!.Status);
        var retryBatch = await context.MusicImportBatches.SingleAsync(candidate => candidate.Id == batch.Id);
        retryItem = await context.MusicImportItems.SingleAsync(item => item.Id == retryItem.Id);
        retryItem.Status = MusicImportItemStatus.Processing;
        retryItem.LeaseOwner = "retry-worker";
        retryItem.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(5);
        await context.SaveChangesAsync();
        await new MusicImportAnalysisProcessor(
            context,
            new MusicImportSourceReader(settings, stack.Storage),
            new RecordingMetadataExtractor(new AudioMetadata(
                "retry", "artist", "album", 60, 900, "flac",
                Codec: "flac", Container: "flac", IsLossless: true,
                SampleRateHz: 44_100, BitDepth: 16, Channels: 2,
                BitRateKbps: 900, ExactDurationMilliseconds: 60_000)),
            new MarkerFingerprintService())
            .AnalyzeAsync(retryItem.Id, "retry-worker");
        retryBatch.Status = MusicImportBatchStatus.Grouping;
        await context.SaveChangesAsync();
        await new MusicImportGroupingService(
            context,
            Options.Create(new AudioFingerprintOptions()))
            .GroupBatchAsync(retryBatch.Id);

        var newGroup = await context.MusicImportReviewGroups
            .SingleAsync(group => group.Id != appliedGroup.Id);
        var review = new MusicImportReviewService(context);
        await review.SaveDecisionAsync(
            newGroup.Id,
            user.Id,
            new MusicImportReviewDecisionRequest(
                newGroup.Version,
                "createTrack",
                [retryItem.Id]));
        var groups = await context.MusicImportReviewGroups
            .Where(group => group.BatchId == retryBatch.Id)
            .OrderBy(group => group.Id)
            .ToArrayAsync();
        await review.LockBatchAsync(
            retryBatch.Id,
            user.Id,
            new MusicImportLockRequest(groups
                .Select(group => new MusicImportReviewVersionRequest(group.Id, group.Version))
                .ToArray()));
        retryBatch.Status = MusicImportBatchStatus.Applying;
        await context.SaveChangesAsync();
        await CreateService(context, stack.SourceDirectory, stack.Storage)
            .ApplyGroupAsync(newGroup.Id, newGroup.Version);

        Assert.Equal(2, await context.Tracks.CountAsync());
        var verifiedGroups = await context.MusicImportReviewGroups
            .Where(group => group.BatchId == retryBatch.Id)
            .ToDictionaryAsync(group => group.Id);
        var verifiedItems = await context.MusicImportItems
            .Where(item => item.BatchId == retryBatch.Id)
            .ToDictionaryAsync(item => item.Id);
        Assert.Equal(MusicImportReviewStatus.Applied, verifiedGroups[appliedGroup.Id].Status);
        Assert.Equal(MusicImportReviewStatus.Applied, verifiedGroups[newGroup.Id].Status);
        Assert.Equal(existingTrack.Id, verifiedItems[appliedItem.Id].TrackId);
        Assert.NotEqual(existingTrack.Id, verifiedItems[retryItem.Id].TrackId);
    }

    private static MusicImportApplyService CreateService(
        FollowDbContext context,
        string sourceRoot,
        IStorageService storage) => new(
        context,
        new MusicImportSourceReader(
            new MusicImportRuntimeSettings
            {
                Enabled = !string.IsNullOrEmpty(sourceRoot),
                SourceRoot = sourceRoot,
                MaximumFileBytes = 10_000
            },
            storage),
        new MarkerFingerprintService(),
        storage,
        new StorageDeletionQueue(context));

    private static FollowDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase($"music-import-e2e-{Guid.NewGuid():N}")
            .Options);

    private static async Task<(MusicImportReviewGroup Group, Track Track)> SeedExistingTrackGroupAsync(
        FollowDbContext context,
        RecordingStorage storage,
        MusicImportDecisionKind decision)
    {
        var user = Admin();
        var track = new Track { Title = "existing", FilePath = "tracks/existing/audio.mp3" };
        var batch = ApplyingBatch(user, MusicImportSourceKind.BrowserStaging);
        var group = LockedGroup(batch, user, track);
        foreach (var marker in new byte[] { 41, 42 })
        {
            var itemId = Guid.NewGuid();
            var staging = ImportObjectPath.BuildStaging(itemId, ".mp3");
            storage.Objects[staging] = Enumerable.Repeat(marker, 128).ToArray();
            group.Items.Add(new MusicImportItem
            {
                Id = itemId,
                Batch = batch,
                BatchId = batch.Id,
                ReviewGroup = group,
                ReviewGroupId = group.Id,
                SourceKind = MusicImportSourceKind.BrowserStaging,
                SourceReference = staging,
                StagingObjectPath = staging,
                RelativePath = $"browser/{itemId:N}/candidate.mp3",
                OriginalFileName = $"candidate-{marker}.mp3",
                Extension = ".mp3",
                SizeBytes = 128,
                Stage = MusicImportItemStage.AwaitingReview,
                Decision = decision,
                DecisionTrackId = track.Id
            });
        }
        context.AddRange(user, track, batch, group);
        await context.SaveChangesAsync();
        return (group, track);
    }

    private static async Task<MusicImportReviewGroup> SeedSeparateGroupAsync(
        FollowDbContext context,
        SourceFile first,
        SourceFile second)
    {
        var user = Admin();
        var batch = ApplyingBatch(user, MusicImportSourceKind.MountedDirectory);
        var group = LockedGroup(batch, user, existingTrack: null);
        group.MatchKind = MusicImportMatchKind.AcousticFingerprint;
        group.Items.Add(Candidate(batch, group, first, MusicImportDecisionKind.TreatAsSeparateRecording));
        group.Items.Add(Candidate(batch, group, second, MusicImportDecisionKind.TreatAsSeparateRecording));
        context.AddRange(user, batch, group);
        await context.SaveChangesAsync();
        return group;
    }

    private static async Task<SeededCreateGroup> SeedCreateGroupAsync(
        FollowDbContext context,
        SourceFile selected,
        SourceFile rejected)
    {
        var user = Admin();
        var batch = ApplyingBatch(user, MusicImportSourceKind.MountedDirectory);
        var group = LockedGroup(batch, user, existingTrack: null);
        var selectedItem = Candidate(batch, group, selected, MusicImportDecisionKind.CreateTrack);
        var rejectedItem = Candidate(batch, group, rejected, MusicImportDecisionKind.RejectDuplicate);
        group.Items.Add(selectedItem);
        group.Items.Add(rejectedItem);
        context.AddRange(user, batch, group);
        await context.SaveChangesAsync();
        return new SeededCreateGroup(group, selectedItem, rejectedItem);
    }

    private static User Admin() => new()
    {
        Username = $"admin-{Guid.NewGuid():N}",
        Email = $"{Guid.NewGuid():N}@example.test",
        PasswordHash = "test",
        Role = UserRole.Admin
    };

    private static MusicImportBatch ApplyingBatch(User user, MusicImportSourceKind sourceKind) => new()
    {
        RequestedByUser = user,
        RequestedByUserId = user.Id,
        ClientRequestId = Guid.NewGuid().ToString("N"),
        SourceKind = sourceKind,
        Status = MusicImportBatchStatus.Applying
    };

    private static MusicImportReviewGroup LockedGroup(
        MusicImportBatch batch,
        User user,
        Track? existingTrack) => new()
    {
        Batch = batch,
        BatchId = batch.Id,
        Status = MusicImportReviewStatus.Locked,
        ExistingTrack = existingTrack,
        ExistingTrackId = existingTrack?.Id,
        ConfirmedByUser = user,
        ConfirmedByUserId = user.Id,
        ConfirmedAt = DateTime.UtcNow
    };

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
            Codec = source.Name.EndsWith(".flac", StringComparison.Ordinal) ? "flac" : "mp3",
            Container = source.Name.EndsWith(".flac", StringComparison.Ordinal) ? "flac" : "mpeg",
            ExactDurationMilliseconds = 60_000,
            ContentSha256 = SHA256.HashData(source.Bytes),
            FingerprintVersion = "1.6.1",
            FingerprintAlgorithm = 2,
            FingerprintPayload = AudioFingerprintPayloadCodec.Encode(frames),
            FingerprintFrameCount = frames.Length,
            FingerprintDurationMilliseconds = 60_000
        };
    }

    private static async Task<SourceFile> WriteSourceAsync(string root, string name, byte marker)
    {
        var bytes = Enumerable.Repeat(marker, 1024).ToArray();
        await File.WriteAllBytesAsync(Path.Combine(root, name), bytes);
        return new SourceFile(
            name,
            bytes,
            marker,
            MusicImportScanner.NormalizeDatabaseTimestamp(
                File.GetLastWriteTimeUtc(Path.Combine(root, name))));
    }

    private sealed record SourceFile(string Name, byte[] Bytes, byte Marker, DateTime ModifiedAt);
    private sealed record SeededCreateGroup(
        MusicImportReviewGroup Group,
        MusicImportItem Selected,
        MusicImportItem Rejected);

    private sealed class MarkerFingerprintService : IAudioFingerprintService
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

    private sealed class RecordingStorage : IStorageService
    {
        public Dictionary<string, byte[]> Objects { get; } = new(StringComparer.Ordinal);
        public List<string> Writes { get; } = [];

        public async Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default)
        {
            using var buffer = new MemoryStream();
            await source.CopyToAsync(buffer, cancellationToken);
            Objects[objectPath] = buffer.ToArray();
            Writes.Add(objectPath);
        }

        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) =>
            Task.FromResult(Objects.TryGetValue(filePath, out var bytes)
                ? new StorageObjectMetadata(bytes.LongLength, "audio/mpeg", null)
                : null);

        public async Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) =>
            await destination.WriteAsync(Objects[filePath].AsMemory((int)offset, (int)length), cancellationToken);

        public Task<bool> DeleteFileAsync(string filePath) => Task.FromResult(Objects.Remove(filePath));
        public Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null) => throw new NotSupportedException();
    }
}
