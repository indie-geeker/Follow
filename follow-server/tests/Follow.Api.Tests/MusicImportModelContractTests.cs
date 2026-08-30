using Follow.Core.Entities;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace Follow.Api.Tests;

public class MusicImportModelContractTests
{
    [Fact]
    public async Task SaveChanges_AdvancesVersionAndRejectsStaleImportUpdate()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        var batchId = Guid.NewGuid();

        await using (var seed = new FollowDbContext(options))
        {
            seed.MusicImportBatches.Add(new MusicImportBatch
            {
                Id = batchId,
                RequestedByUserId = Guid.NewGuid(),
                ClientRequestId = "concurrency-contract"
            });
            await seed.SaveChangesAsync();
        }

        await using var first = new FollowDbContext(options);
        await using var stale = new FollowDbContext(options);
        var firstCopy = await first.MusicImportBatches.SingleAsync(batch => batch.Id == batchId);
        var staleCopy = await stale.MusicImportBatches.SingleAsync(batch => batch.Id == batchId);

        firstCopy.Status = MusicImportBatchStatus.Scanning;
        await first.SaveChangesAsync();

        Assert.Equal(1, firstCopy.Version);

        staleCopy.Status = MusicImportBatchStatus.CancelRequested;
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => stale.SaveChangesAsync());
    }

    [Fact]
    public void Model_ContainsDurableImportEntitiesAndStringStatuses()
    {
        using var context = CreateContext();
        var batch = context.Model.FindEntityType(typeof(MusicImportBatch));
        var item = context.Model.FindEntityType(typeof(MusicImportItem));

        Assert.NotNull(batch);
        Assert.NotNull(item);
        Assert.Equal(
            typeof(string),
            GetProviderType(batch!.FindProperty(nameof(MusicImportBatch.Status))!));
        Assert.Equal(
            typeof(string),
            GetProviderType(item!.FindProperty(nameof(MusicImportItem.Status))!));
        Assert.Equal(
            typeof(string),
            GetProviderType(item.FindProperty(nameof(MusicImportItem.Stage))!));
    }

    [Fact]
    public void Model_DefinesBatchItemAndClaimIndexes()
    {
        using var context = CreateContext();
        var batch = context.Model.FindEntityType(typeof(MusicImportBatch))!;
        var item = context.Model.FindEntityType(typeof(MusicImportItem))!;

        Assert.Contains(batch.GetIndexes(), index =>
            index.IsUnique && HasProperties(
                index,
                nameof(MusicImportBatch.RequestedByUserId),
                nameof(MusicImportBatch.ClientRequestId)));
        Assert.Equal(
            "UX_MusicImportBatches_RequestedByUser_ClientRequestId",
            Assert.Single(batch.GetIndexes(), index =>
                index.IsUnique && HasProperties(
                    index,
                    nameof(MusicImportBatch.RequestedByUserId),
                    nameof(MusicImportBatch.ClientRequestId))).GetDatabaseName());
        Assert.Contains(item.GetIndexes(), index =>
            index.IsUnique && HasProperties(
                index,
                nameof(MusicImportItem.BatchId),
                nameof(MusicImportItem.RelativePath)));
        Assert.Contains(item.GetIndexes(), index => HasProperties(
            index,
            nameof(MusicImportItem.BatchId),
            nameof(MusicImportItem.Status)));
        Assert.Contains(item.GetIndexes(), index => HasProperties(
            index,
            nameof(MusicImportItem.Status),
            nameof(MusicImportItem.NextAttemptAt),
            nameof(MusicImportItem.LeaseExpiresAt)));
    }

    [Fact]
    public void Model_DefinesFilteredUniqueTrackHash()
    {
        using var context = CreateContext();
        var track = context.Model.FindEntityType(typeof(Track))!;
        var hash = track.FindProperty(nameof(Track.ContentSha256));
        var index = Assert.Single(track.GetIndexes(), candidate =>
            HasProperties(candidate, nameof(Track.ContentSha256)));

        Assert.NotNull(hash);
        Assert.True(hash!.IsNullable);
        Assert.Equal(32, hash.GetMaxLength());
        Assert.True(index.IsUnique);
        Assert.Equal("UX_Tracks_ContentSha256", index.GetDatabaseName());
        Assert.Contains("ContentSha256", index.GetFilter());
        Assert.Contains("IS NOT NULL", index.GetFilter());
    }

    [Fact]
    public void Model_BoundsAuditPathsLeasesAndErrors()
    {
        using var context = CreateContext();
        var batch = context.Model.FindEntityType(typeof(MusicImportBatch))!;
        var item = context.Model.FindEntityType(typeof(MusicImportItem))!;

        Assert.Equal(64, batch.FindProperty(nameof(MusicImportBatch.ClientRequestId))!.GetMaxLength());
        Assert.Equal(1024, batch.FindProperty(nameof(MusicImportBatch.RelativeDirectory))!.GetMaxLength());
        Assert.Equal(2048, batch.FindProperty(nameof(MusicImportBatch.LastError))!.GetMaxLength());
        Assert.Equal(1024, item.FindProperty(nameof(MusicImportItem.RelativePath))!.GetMaxLength());
        Assert.Equal(1024, item.FindProperty(nameof(MusicImportItem.ObjectPath))!.GetMaxLength());
        Assert.Equal(64, item.FindProperty(nameof(MusicImportItem.ErrorCode))!.GetMaxLength());
        Assert.Equal(2048, item.FindProperty(nameof(MusicImportItem.ErrorMessage))!.GetMaxLength());
    }

    [Fact]
    public void Npgsql_TranslatesContentHashSequenceEqualToByteaEquality()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseNpgsql(
                "Host=127.0.0.1;Database=translation_only;Username=translation;Password=translation")
            .Options;
        using var context = new FollowDbContext(options);
        var hash = new byte[32];

        var trackSql = context.Tracks
            .Where(track => track.ContentSha256 != null &&
                track.ContentSha256.SequenceEqual(hash))
            .ToQueryString();
        var itemSql = context.MusicImportItems
            .Where(item => item.ContentSha256 != null &&
                item.ContentSha256.SequenceEqual(hash))
            .ToQueryString();

        Assert.Matches("\\\"ContentSha256\\\"\\s*=\\s*@(?:__)?hash", trackSql);
        Assert.Matches("\\\"ContentSha256\\\"\\s*=\\s*@(?:__)?hash", itemSql);
    }

    private static bool HasProperties(IIndex index, params string[] names) =>
        index.Properties.Select(property => property.Name).SequenceEqual(names);

    private static Type? GetProviderType(IProperty property) =>
        property.GetValueConverter()?.ProviderClrType
        ?? property.GetTypeMapping().Converter?.ProviderClrType;

    private static FollowDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FollowDbContext(options);
    }
}
