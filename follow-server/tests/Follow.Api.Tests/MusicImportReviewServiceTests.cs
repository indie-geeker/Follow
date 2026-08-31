using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public class MusicImportReviewServiceTests
{
    [Theory]
    [InlineData("createTrack", false, 1, MusicImportReviewStatus.Confirmed)]
    [InlineData("replaceExistingTrack", true, 1, MusicImportReviewStatus.Confirmed)]
    [InlineData("keepExistingTrack", true, 2, MusicImportReviewStatus.Confirmed)]
    [InlineData("treatAsSeparateRecording", false, 2, MusicImportReviewStatus.Confirmed)]
    [InlineData("rejectDuplicate", true, 2, MusicImportReviewStatus.Confirmed)]
    [InlineData("defer", false, 2, MusicImportReviewStatus.Deferred)]
    public async Task SaveDecision_PersistsEveryApprovedExplicitDecision(
        string decisionKind,
        bool withExistingTrack,
        int selectedCount,
        MusicImportReviewStatus expectedStatus)
    {
        await using var context = CreateContext();
        var seeded = await SeedGroupAsync(context, withExistingTrack);
        var selected = seeded.Items.Take(selectedCount).Select(item => item.Id).ToArray();
        var actor = Guid.NewGuid();
        var service = new MusicImportReviewService(context);

        var result = await service.SaveDecisionAsync(
            seeded.Group.Id,
            actor,
            new MusicImportReviewDecisionRequest(0, decisionKind, selected));

        Assert.Equal(expectedStatus.ToString(), result.Status, ignoreCase: true);
        Assert.Equal(1, result.Version);
        Assert.Equal(actor, result.ConfirmedByUserId);
        Assert.All(await context.MusicImportItems
            .Where(item => item.ReviewGroupId == seeded.Group.Id)
            .ToListAsync(), item => Assert.NotNull(item.Decision));
    }

    [Fact]
    public async Task SaveDecision_RejectsRecommendationOnlyAndCrossGroupCandidates()
    {
        await using var context = CreateContext();
        var first = await SeedGroupAsync(context, false);
        var second = await SeedGroupAsync(context, false);
        var service = new MusicImportReviewService(context);

        await Assert.ThrowsAsync<ArgumentException>(() => service.SaveDecisionAsync(
            first.Group.Id,
            Guid.NewGuid(),
            new MusicImportReviewDecisionRequest(0, "createTrack", [])));
        await Assert.ThrowsAsync<ArgumentException>(() => service.SaveDecisionAsync(
            first.Group.Id,
            Guid.NewGuid(),
            new MusicImportReviewDecisionRequest(
                0,
                "createTrack",
                [second.Items[0].Id])));
    }

    [Fact]
    public async Task SaveDecision_RejectsReplacementWithoutExistingTrackAndStaleVersion()
    {
        await using var context = CreateContext();
        var seeded = await SeedGroupAsync(context, false);
        var service = new MusicImportReviewService(context);

        await Assert.ThrowsAsync<ArgumentException>(() => service.SaveDecisionAsync(
            seeded.Group.Id,
            Guid.NewGuid(),
            new MusicImportReviewDecisionRequest(
                0,
                "replaceExistingTrack",
                [seeded.Items[0].Id])));
        var conflict = await Assert.ThrowsAsync<MusicImportReviewConflictException>(() =>
            service.SaveDecisionAsync(
                seeded.Group.Id,
                Guid.NewGuid(),
                new MusicImportReviewDecisionRequest(
                    9,
                    "createTrack",
                    [seeded.Items[0].Id])));
        Assert.Equal(0, conflict.Current.Version);
    }

    [Fact]
    public async Task SaveDecision_RejectsSeparateRecordingsForExactShaGroup()
    {
        await using var context = CreateContext();
        var seeded = await SeedGroupAsync(context, false);
        seeded.Group.MatchKind = MusicImportMatchKind.ExactSha256;
        await context.SaveChangesAsync();

        var exception = await Assert.ThrowsAsync<ArgumentException>(() =>
            new MusicImportReviewService(context).SaveDecisionAsync(
                seeded.Group.Id,
                Guid.NewGuid(),
                new MusicImportReviewDecisionRequest(
                    seeded.Group.Version,
                    "treatAsSeparateRecording",
                    seeded.Items.Select(item => item.Id).ToArray())));

        Assert.Contains("byte-identical", exception.Message, StringComparison.OrdinalIgnoreCase);
        Assert.All(seeded.Items, item => Assert.Null(item.Decision));
    }

    [Fact]
    public async Task LockBatch_RequiresAllGroupsConfirmedAndEveryAdvertisedVersion()
    {
        await using var context = CreateContext();
        var first = await SeedGroupAsync(context, false);
        var second = await AddGroupAsync(context, first.Batch, false);
        var service = new MusicImportReviewService(context);
        await ConfirmCreateAsync(service, first);

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.LockBatchAsync(
            first.Batch.Id,
            Guid.NewGuid(),
            new MusicImportLockRequest([
                new MusicImportReviewVersionRequest(first.Group.Id, 1),
                new MusicImportReviewVersionRequest(second.Group.Id, 0)
            ])));

        await ConfirmCreateAsync(service, second);
        await Assert.ThrowsAsync<ArgumentException>(() => service.LockBatchAsync(
            first.Batch.Id,
            Guid.NewGuid(),
            new MusicImportLockRequest([
                new MusicImportReviewVersionRequest(first.Group.Id, 1)
            ])));

        var locked = await service.LockBatchAsync(
            first.Batch.Id,
            Guid.NewGuid(),
            new MusicImportLockRequest([
                new MusicImportReviewVersionRequest(first.Group.Id, 1),
                new MusicImportReviewVersionRequest(second.Group.Id, 1)
            ]));

        Assert.Equal("readyToApply", locked.Status);
        Assert.All(await context.MusicImportReviewGroups
            .Where(group => group.BatchId == first.Batch.Id)
            .ToListAsync(), group => Assert.Equal(MusicImportReviewStatus.Locked, group.Status));
        await Assert.ThrowsAnyAsync<InvalidOperationException>(() => service.LockBatchAsync(
            first.Batch.Id,
            Guid.NewGuid(),
            new MusicImportLockRequest([
                new MusicImportReviewVersionRequest(first.Group.Id, 2),
                new MusicImportReviewVersionRequest(second.Group.Id, 2)
            ])));
    }

    [Fact]
    public async Task LockBatch_PreservesAppliedGroupsAndLocksOnlyNewlyConfirmedGroups()
    {
        await using var context = CreateContext();
        var applied = await SeedGroupAsync(context, false);
        applied.Group.Status = MusicImportReviewStatus.Applied;
        await context.SaveChangesAsync();
        var pending = await AddGroupAsync(context, applied.Batch, false);
        var service = new MusicImportReviewService(context);
        await ConfirmCreateAsync(service, pending);

        var result = await service.LockBatchAsync(
            applied.Batch.Id,
            Guid.NewGuid(),
            new MusicImportLockRequest([
                new MusicImportReviewVersionRequest(applied.Group.Id, applied.Group.Version),
                new MusicImportReviewVersionRequest(pending.Group.Id, pending.Group.Version)
            ]));

        Assert.Equal("readyToApply", result.Status);
        Assert.Equal(MusicImportReviewStatus.Applied, applied.Group.Status);
        Assert.Equal(MusicImportReviewStatus.Locked, pending.Group.Status);
    }

    [Fact]
    public async Task GetGroup_ExposesQualityMatchRecommendationAndSafePreviewLinks()
    {
        await using var context = CreateContext();
        var seeded = await SeedGroupAsync(context, true);
        seeded.Group.MatchKind = MusicImportMatchKind.AcousticFingerprint;
        seeded.Group.OverallSimilarity = .98;
        seeded.Group.RecommendedItemId = seeded.Items[0].Id;
        seeded.Group.RecommendationExplanation = "lossless source";
        await context.SaveChangesAsync();

        var dto = await new MusicImportReviewService(context).GetGroupAsync(seeded.Group.Id);

        Assert.NotNull(dto);
        Assert.Equal(.98, dto.OverallSimilarity);
        Assert.Equal(seeded.Items[0].Id, dto.RecommendedItemId);
        Assert.All(dto.Candidates, candidate =>
        {
            Assert.StartsWith("/api/admin/music-imports/items/", candidate.PreviewUrl);
            Assert.DoesNotContain(Path.GetTempPath(), candidate.PreviewUrl);
        });
    }

    private static async Task ConfirmCreateAsync(
        MusicImportReviewService service,
        SeededGroup seeded) =>
        await service.SaveDecisionAsync(
            seeded.Group.Id,
            Guid.NewGuid(),
            new MusicImportReviewDecisionRequest(
                seeded.Group.Version,
                "createTrack",
                [seeded.Items[0].Id]));

    private static FollowDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase($"review-{Guid.NewGuid():N}")
            .Options;
        return new FollowDbContext(options);
    }

    private static async Task<SeededGroup> SeedGroupAsync(
        FollowDbContext context,
        bool withExistingTrack)
    {
        var batch = new MusicImportBatch
        {
            RequestedByUserId = Guid.NewGuid(),
            ClientRequestId = Guid.NewGuid().ToString("N"),
            Status = MusicImportBatchStatus.AwaitingReview
        };
        context.MusicImportBatches.Add(batch);
        return await AddGroupAsync(context, batch, withExistingTrack);
    }

    private static async Task<SeededGroup> AddGroupAsync(
        FollowDbContext context,
        MusicImportBatch batch,
        bool withExistingTrack)
    {
        Track? track = withExistingTrack
            ? new Track { Title = "existing", FilePath = "tracks/existing.mp3" }
            : null;
        if (track != null) context.Tracks.Add(track);
        var group = new MusicImportReviewGroup
        {
            Batch = batch,
            BatchId = batch.Id,
            ExistingTrack = track,
            ExistingTrackId = track?.Id,
            Status = MusicImportReviewStatus.Open
        };
        var items = new[]
        {
            Candidate(batch, group, "one.flac", true),
            Candidate(batch, group, "two.mp3", false)
        };
        context.AddRange(group, items[0], items[1]);
        await context.SaveChangesAsync();
        return new SeededGroup(batch, group, items);
    }

    private static MusicImportItem Candidate(
        MusicImportBatch batch,
        MusicImportReviewGroup group,
        string name,
        bool lossless) => new()
    {
        Batch = batch,
        BatchId = batch.Id,
        ReviewGroup = group,
        ReviewGroupId = group.Id,
        RelativePath = $"safe/{name}",
        OriginalFileName = name,
        Extension = Path.GetExtension(name),
        SizeBytes = lossless ? 2_000 : 1_000,
        SourceModifiedAt = DateTime.UtcNow,
        Stage = MusicImportItemStage.Grouped,
        ExtractedTitle = "title",
        ExtractedArtist = "artist",
        Codec = lossless ? "flac" : "mp3",
        Container = lossless ? "flac" : "mpeg",
        IsLossless = lossless,
        SampleRateHz = 44_100,
        BitDepth = lossless ? 16 : null,
        Channels = 2,
        BitRateKbps = lossless ? 900 : 320,
        ExactDurationMilliseconds = 123_456
    };

    internal sealed record SeededGroup(
        MusicImportBatch Batch,
        MusicImportReviewGroup Group,
        MusicImportItem[] Items);
}
