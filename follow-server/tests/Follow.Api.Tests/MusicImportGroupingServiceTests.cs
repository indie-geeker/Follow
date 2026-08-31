using Follow.Core.Entities;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Options;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Follow.Api.Tests;

public class MusicImportGroupingServiceTests
{
    [Fact]
    public async Task ExactHashCandidates_FormOpenReviewGroupWithoutAutomaticDecision()
    {
        await using var context = CreateContext();
        var batch = await SeedBatchAsync(context);
        var hash = Enumerable.Repeat((byte)7, 32).ToArray();
        AddAnalyzedItem(context, batch, "a.flac", hash, [1, 2, 3]);
        AddAnalyzedItem(context, batch, "b.mp3", hash, [9, 9, 9]);
        await context.SaveChangesAsync();

        await CreateService(context).GroupBatchAsync(batch.Id);

        var group = Assert.Single(await context.MusicImportReviewGroups.ToListAsync());
        var items = await context.MusicImportItems.OrderBy(item => item.RelativePath).ToListAsync();
        Assert.Equal(MusicImportMatchKind.ExactSha256, group.MatchKind);
        Assert.Equal(MusicImportReviewStatus.Open, group.Status);
        Assert.All(items, item => Assert.Equal(group.Id, item.ReviewGroupId));
        Assert.All(items, item => Assert.Null(item.Decision));
        Assert.All(items, item => Assert.Equal(MusicImportItemStage.Grouped, item.Stage));
        Assert.NotNull(group.RecommendedItemId);
        Assert.False(string.IsNullOrWhiteSpace(group.RecommendationExplanation));
        Assert.Empty(await context.Tracks.ToListAsync());
    }

    [Fact]
    public async Task Fingerprints_GroupOnlyCalibratedMatchesAndIgnoreMetadataOnlySimilarity()
    {
        await using var context = CreateContext();
        var batch = await SeedBatchAsync(context);
        var matching = Enumerable.Repeat(0x12345678u, 80).ToArray();
        var different = Enumerable.Repeat(0xfedcba98u, 80).ToArray();
        AddAnalyzedItem(context, batch, "same-a.flac", Hash(1), matching, title: "same title");
        AddAnalyzedItem(context, batch, "same-b.mp3", Hash(2), matching, title: "same title");
        AddAnalyzedItem(context, batch, "metadata-only.mp3", Hash(3), different, title: "same title");
        await context.SaveChangesAsync();

        await CreateService(context).GroupBatchAsync(batch.Id);

        var groups = await context.MusicImportReviewGroups.OrderBy(group => group.CreatedAt).ToListAsync();
        var items = await context.MusicImportItems.ToDictionaryAsync(item => item.RelativePath);
        Assert.Equal(2, groups.Count);
        Assert.Equal(items["same-a.flac"].ReviewGroupId, items["same-b.mp3"].ReviewGroupId);
        Assert.NotEqual(items["same-a.flac"].ReviewGroupId, items["metadata-only.mp3"].ReviewGroupId);
        var matchGroup = groups.Single(group => group.Id == items["same-a.flac"].ReviewGroupId);
        Assert.Equal(MusicImportMatchKind.AcousticFingerprint, matchGroup.MatchKind);
        Assert.Equal(1d, matchGroup.OverallSimilarity);
        var standalone = groups.Single(group => group.Id == items["metadata-only.mp3"].ReviewGroupId);
        Assert.Equal(MusicImportMatchKind.None, standalone.MatchKind);
    }

    [Fact]
    public async Task CompatibleExistingTrackSeedsGroupButTrackWithoutFingerprintDoesNot()
    {
        await using var context = CreateContext();
        var batch = await SeedBatchAsync(context);
        var frames = Enumerable.Repeat(0x12345678u, 80).ToArray();
        var item = AddAnalyzedItem(context, batch, "candidate.flac", Hash(4), frames);
        var compatible = TrackWithFingerprint("compatible", frames);
        var legacy = new Track { Title = "legacy", FilePath = "tracks/legacy.mp3" };
        context.Tracks.AddRange(compatible, legacy);
        await context.SaveChangesAsync();

        await CreateService(context).GroupBatchAsync(batch.Id);

        var group = await context.MusicImportReviewGroups.SingleAsync();
        Assert.Equal(compatible.Id, group.ExistingTrackId);
        Assert.NotEqual(legacy.Id, group.ExistingTrackId);
        Assert.Equal(MusicImportMatchKind.AcousticFingerprint, group.MatchKind);
        Assert.Equal(group.Id, item.ReviewGroupId);
    }

    [Fact]
    public async Task ExactHashGroupingIncludesCandidatesBeyondTheFirstPage()
    {
        await using var context = CreateContext();
        var batch = await SeedBatchAsync(context);
        var hash = Hash(8);
        for (var index = 0; index < 202; index++)
        {
            AddAnalyzedItem(
                context,
                batch,
                $"exact-{index:D3}.flac",
                hash,
                [(uint)(index + 1)]);
        }
        await context.SaveChangesAsync();

        await CreateService(context).GroupBatchAsync(batch.Id);

        var group = Assert.Single(await context.MusicImportReviewGroups.ToListAsync());
        Assert.Equal(MusicImportMatchKind.ExactSha256, group.MatchKind);
        Assert.Equal(202, await context.MusicImportItems.CountAsync(item => item.ReviewGroupId == group.Id));
    }

    [Fact]
    public async Task AcousticGroupingIncludesCandidatesBeyondTheFirstPage()
    {
        await using var context = CreateContext();
        var batch = await SeedBatchAsync(context);
        var frames = Enumerable.Repeat(0x12345678u, 80).ToArray();
        for (var index = 0; index < 202; index++)
        {
            AddAnalyzedItem(
                context,
                batch,
                $"acoustic-{index:D3}.flac",
                Hash((byte)(index % 251 + 1)),
                frames);
        }
        await context.SaveChangesAsync();

        await CreateService(context).GroupBatchAsync(batch.Id);

        var group = Assert.Single(await context.MusicImportReviewGroups.ToListAsync());
        Assert.Equal(MusicImportMatchKind.AcousticFingerprint, group.MatchKind);
        Assert.Equal(202, await context.MusicImportItems.CountAsync(item => item.ReviewGroupId == group.Id));
    }

    [Fact]
    public async Task ExistingTrackMatchingSearchesBeyondTheFirstPage()
    {
        await using var context = CreateContext();
        var batch = await SeedBatchAsync(context);
        var matchingFrames = Enumerable.Repeat(0x12345678u, 80).ToArray();
        AddAnalyzedItem(context, batch, "candidate.flac", Hash(9), matchingFrames);
        for (var index = 0; index < 200; index++)
        {
            var different = TrackWithFingerprint(
                $"different-{index:D3}",
                Enumerable.Repeat((uint)index, 80).ToArray());
            different.CreatedAt = DateTime.UnixEpoch.AddSeconds(index);
            context.Tracks.Add(different);
        }
        var matching = TrackWithFingerprint("matching-201", matchingFrames);
        matching.CreatedAt = DateTime.UnixEpoch.AddSeconds(201);
        context.Tracks.Add(matching);
        await context.SaveChangesAsync();

        await CreateService(context).GroupBatchAsync(batch.Id);

        var group = await context.MusicImportReviewGroups.SingleAsync();
        Assert.Equal(matching.Id, group.ExistingTrackId);
        Assert.Equal(MusicImportMatchKind.AcousticFingerprint, group.MatchKind);
    }

    [Fact]
    public async Task GroupingRefusesToStartUntilEveryEligibleItemIsAnalyzed()
    {
        await using var context = CreateContext();
        var batch = await SeedBatchAsync(context);
        AddAnalyzedItem(context, batch, "ready.flac", Hash(1), [1, 2, 3]);
        var pending = AddAnalyzedItem(context, batch, "pending.flac", Hash(2), [4, 5, 6]);
        pending.Stage = MusicImportItemStage.Hashing;
        await context.SaveChangesAsync();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateService(context).GroupBatchAsync(batch.Id));

        Assert.Empty(await context.MusicImportReviewGroups.ToListAsync());
    }

    private static MusicImportGroupingService CreateService(FollowDbContext context) => new(
        context,
        Options.Create(new AudioFingerprintOptions()));

    private static async Task<MusicImportBatch> SeedBatchAsync(FollowDbContext context)
    {
        var batch = new MusicImportBatch
        {
            RequestedByUserId = Guid.NewGuid(),
            ClientRequestId = Guid.NewGuid().ToString("N"),
            Status = MusicImportBatchStatus.Grouping
        };
        context.MusicImportBatches.Add(batch);
        await context.SaveChangesAsync();
        return batch;
    }

    private static MusicImportItem AddAnalyzedItem(
        FollowDbContext context,
        MusicImportBatch batch,
        string relativePath,
        byte[] hash,
        IReadOnlyList<uint> frames,
        string title = "title")
    {
        var item = new MusicImportItem
        {
            Batch = batch,
            BatchId = batch.Id,
            RelativePath = relativePath,
            OriginalFileName = Path.GetFileName(relativePath),
            Extension = Path.GetExtension(relativePath),
            SizeBytes = 100,
            SourceModifiedAt = DateTime.UtcNow,
            Status = MusicImportItemStatus.Pending,
            Stage = MusicImportItemStage.Analyzed,
            ContentSha256 = hash,
            ExtractedTitle = title,
            Codec = relativePath.EndsWith(".flac") ? "flac" : "mp3",
            Container = Path.GetExtension(relativePath).TrimStart('.'),
            IsLossless = relativePath.EndsWith(".flac"),
            FingerprintVersion = "1.6.1",
            FingerprintAlgorithm = 2,
            FingerprintPayload = AudioFingerprintPayloadCodec.Encode(frames),
            FingerprintFrameCount = frames.Count,
            FingerprintDurationMilliseconds = 10_000
        };
        context.MusicImportItems.Add(item);
        return item;
    }

    private static Track TrackWithFingerprint(string title, IReadOnlyList<uint> frames) => new()
    {
        Title = title,
        FilePath = $"tracks/{title}.flac",
        FingerprintVersion = "1.6.1",
        FingerprintAlgorithm = 2,
        FingerprintPayload = AudioFingerprintPayloadCodec.Encode(frames),
        FingerprintFrameCount = frames.Count,
        FingerprintDurationMilliseconds = 10_000
    };

    private static byte[] Hash(byte value) => Enumerable.Repeat(value, 32).ToArray();

    private static FollowDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);
}
