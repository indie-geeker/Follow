using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql;

namespace Follow.Api.Tests;

public class MusicImportMigrationTests
{
    private const string PriorMigration = "20260727061608_AddMusicLibraryInitialization";

    [Fact]
    public async Task EmptyDatabase_MigratesToLatestReviewSchema()
    {
        await WithDisposableDatabaseAsync(async connectionString =>
        {
            await using var context = CreateContext(connectionString);
            await context.Database.MigrateAsync();

            var migrations = (await context.Database.GetAppliedMigrationsAsync()).ToArray();
            Assert.EndsWith("_AddMusicIngestionReview", migrations[^1], StringComparison.Ordinal);

            await using var connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync();
            await using var command = new NpgsqlCommand("""
                SELECT
                    to_regclass('public."MusicImportReviewGroups"') IS NOT NULL,
                    to_regclass('public."TrackAudioRevisions"') IS NOT NULL,
                    EXISTS (
                        SELECT 1 FROM information_schema.columns
                        WHERE table_schema = 'public'
                          AND table_name = 'Tracks'
                          AND column_name = 'FingerprintPayload')
                """, connection);
            await using var reader = await command.ExecuteReaderAsync();
            Assert.True(await reader.ReadAsync());
            Assert.True(reader.GetBoolean(0));
            Assert.True(reader.GetBoolean(1));
            Assert.True(reader.GetBoolean(2));
        });
    }

    [Fact]
    public async Task PriorDatabase_PreservesOldTrackWhenMigratedForward()
    {
        await WithDisposableDatabaseAsync(async connectionString =>
        {
            var trackId = Guid.NewGuid();
            await using (var priorContext = CreateContext(connectionString))
            {
                var migrator = priorContext.GetService<IMigrator>();
                await migrator.MigrateAsync(PriorMigration);
            }

            await using (var connection = new NpgsqlConnection(connectionString))
            {
                await connection.OpenAsync();
                await using var insert = new NpgsqlCommand("""
                    INSERT INTO "Tracks"
                        ("Id", "Title", "DurationSeconds", "FilePath", "BitRate", "Format", "CreatedAt", "UpdatedAt")
                    VALUES
                        (@id, 'legacy track', 123, 'tracks/legacy.mp3', 192, 'mp3', now(), now())
                    """, connection);
                insert.Parameters.AddWithValue("id", trackId);
                Assert.Equal(1, await insert.ExecuteNonQueryAsync());
            }

            await using (var currentContext = CreateContext(connectionString))
            {
                await currentContext.Database.MigrateAsync();
                var track = await currentContext.Tracks.AsNoTracking().SingleAsync(candidate => candidate.Id == trackId);

                Assert.Equal("legacy track", track.Title);
                Assert.Null(track.Codec);
                Assert.Null(track.ExactDurationMilliseconds);
                Assert.Null(track.FingerprintPayload);
                Assert.Null(track.FingerprintVersion);
            }
        });
    }

    private static FollowDbContext CreateContext(string connectionString)
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseNpgsql(connectionString)
            .Options;
        return new FollowDbContext(options);
    }

    private static async Task WithDisposableDatabaseAsync(Func<string, Task> test)
    {
        var adminConnectionString = Environment.GetEnvironmentVariable("FOLLOW_TEST_POSTGRES");
        if (string.IsNullOrWhiteSpace(adminConnectionString))
            throw new InvalidOperationException("FOLLOW_TEST_POSTGRES is required for real migration tests.");

        var databaseName = $"follow_ingestion_{Guid.NewGuid():N}";
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
            await using var drop = new NpgsqlCommand($"DROP DATABASE \"{databaseName}\" WITH (FORCE)", admin);
            await drop.ExecuteNonQueryAsync();
        }
    }
}
