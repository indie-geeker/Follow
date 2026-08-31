using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Follow.Api.Tests;

public class MusicImportReviewConcurrencyTests
{
    [Fact]
    public async Task PostgreSql_SameExpectedVersionAllowsExactlyOneDecisionWinner()
    {
        await WithDisposableDatabaseAsync(async connectionString =>
        {
            Guid groupId;
            Guid firstItemId;
            Guid secondItemId;
            Guid actingUserId;
            await using (var seed = CreateContext(connectionString))
            {
                await seed.Database.MigrateAsync();
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
                    Status = MusicImportBatchStatus.AwaitingReview
                };
                var group = new MusicImportReviewGroup
                {
                    Batch = batch,
                    BatchId = batch.Id,
                    Status = MusicImportReviewStatus.Open
                };
                var first = Candidate(batch, group, "first.flac");
                var second = Candidate(batch, group, "second.mp3");
                seed.AddRange(user, batch, group, first, second);
                await seed.SaveChangesAsync();
                actingUserId = user.Id;
                groupId = group.Id;
                firstItemId = first.Id;
                secondItemId = second.Id;
            }

            var firstAttempt = SubmitAsync(connectionString, groupId, firstItemId, actingUserId);
            var secondAttempt = SubmitAsync(connectionString, groupId, secondItemId, actingUserId);
            var outcomes = await Task.WhenAll(firstAttempt, secondAttempt);

            Assert.Single(outcomes, outcome => outcome == "success");
            Assert.Single(outcomes, outcome => outcome == "conflict");
            await using var verify = CreateContext(connectionString);
            Assert.Equal(1, (await verify.MusicImportReviewGroups
                .AsNoTracking()
                .SingleAsync(group => group.Id == groupId)).Version);
        });
    }

    private static async Task<string> SubmitAsync(
        string connectionString,
        Guid groupId,
        Guid selectedItemId,
        Guid actingUserId)
    {
        await using var context = CreateContext(connectionString);
        var service = new MusicImportReviewService(context);
        try
        {
            await service.SaveDecisionAsync(
                groupId,
                actingUserId,
                new MusicImportReviewDecisionRequest(
                    0,
                    "createTrack",
                    [selectedItemId]));
            return "success";
        }
        catch (MusicImportReviewConflictException exception)
        {
            Assert.Equal(1, exception.Current.Version);
            return "conflict";
        }
    }

    private static MusicImportItem Candidate(
        MusicImportBatch batch,
        MusicImportReviewGroup group,
        string name) => new()
    {
        Batch = batch,
        BatchId = batch.Id,
        ReviewGroup = group,
        ReviewGroupId = group.Id,
        RelativePath = $"safe/{name}",
        OriginalFileName = name,
        Extension = Path.GetExtension(name),
        SizeBytes = 100,
        SourceModifiedAt = DateTime.UtcNow,
        Stage = MusicImportItemStage.Grouped,
        ExtractedTitle = "title"
    };

    private static FollowDbContext CreateContext(string connectionString) => new(
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseNpgsql(connectionString)
            .Options);

    private static async Task WithDisposableDatabaseAsync(Func<string, Task> test)
    {
        var adminConnectionString = Environment.GetEnvironmentVariable("FOLLOW_TEST_POSTGRES");
        if (string.IsNullOrWhiteSpace(adminConnectionString))
            throw new InvalidOperationException("FOLLOW_TEST_POSTGRES is required for concurrency tests.");

        var databaseName = $"follow_review_{Guid.NewGuid():N}";
        var adminBuilder = new NpgsqlConnectionStringBuilder(adminConnectionString);
        var databaseBuilder = new NpgsqlConnectionStringBuilder(adminConnectionString)
        {
            Database = databaseName,
            Pooling = false
        };
        await using var admin = new NpgsqlConnection(adminBuilder.ConnectionString);
        await admin.OpenAsync();
        await using (var create = new NpgsqlCommand($"CREATE DATABASE \"{databaseName}\"", admin))
            await create.ExecuteNonQueryAsync();
        try
        {
            await test(databaseBuilder.ConnectionString);
        }
        finally
        {
            await using var drop = new NpgsqlCommand(
                $"DROP DATABASE \"{databaseName}\" WITH (FORCE)",
                admin);
            await drop.ExecuteNonQueryAsync();
        }
    }
}
