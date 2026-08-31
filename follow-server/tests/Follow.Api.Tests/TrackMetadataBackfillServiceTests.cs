using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Follow.Shared.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public sealed class TrackMetadataBackfillServiceTests
{
    private static readonly Guid FirstId = Guid.Parse("00000000-0000-0000-0000-000000000001");
    private static readonly Guid SecondId = Guid.Parse("00000000-0000-0000-0000-000000000002");
    private static readonly Guid ThirdId = Guid.Parse("00000000-0000-0000-0000-000000000003");

    [Fact]
    public async Task RunAsync_UsesStableIdOrderingAfterIdAndBoundedLimit()
    {
        await using var context = CreateContext();
        context.Tracks.AddRange(Track(ThirdId), Track(FirstId), Track(SecondId));
        await context.SaveChangesAsync();
        var fixture = CreateFixture(context);

        var response = await fixture.Service.RunAsync(
            new TrackMetadataBackfillRequest(true, FirstId, 1));

        Assert.Equal([SecondId], response.Entries.Select(entry => entry.TrackId));
        Assert.Equal(SecondId, response.NextAfterId);
        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() =>
            fixture.Service.RunAsync(new TrackMetadataBackfillRequest(true, null, 0)));
        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() =>
            fixture.Service.RunAsync(new TrackMetadataBackfillRequest(true, null, 101)));
    }

    [Fact]
    public async Task RunAsync_DryRunReportsSupportedAssetsWithoutWrites()
    {
        await using var context = CreateContext();
        var track = Track(FirstId);
        context.Tracks.Add(track);
        await context.SaveChangesAsync();
        var fixture = CreateFixture(context, MetadataWithAssets());

        var response = await fixture.Service.RunAsync(
            new TrackMetadataBackfillRequest(true, null, 10));

        Assert.Equal(1, response.CandidateCount);
        Assert.Equal(1, response.SupportedCoverCount);
        Assert.Equal(1, response.SupportedLyricsCount);
        Assert.Equal(0, response.UpdatedCount);
        Assert.Empty(fixture.Storage.Uploads);
        context.ChangeTracker.Clear();
        var persisted = await context.Tracks.SingleAsync();
        Assert.Null(persisted.CoverUrl);
        Assert.Null(persisted.LyricsUrl);
    }

    [Fact]
    public async Task RunAsync_FillsOnlyNullReferencesAndIsIdempotent()
    {
        await using var context = CreateContext();
        var track = Track(FirstId);
        track.CoverUrl = "covers/admin/manual.jpg";
        context.Tracks.Add(track);
        await context.SaveChangesAsync();
        var fixture = CreateFixture(context, MetadataWithAssets());

        var first = await fixture.Service.RunAsync(
            new TrackMetadataBackfillRequest(false, null, 10));
        var uploadCount = fixture.Storage.Uploads.Count;
        var second = await fixture.Service.RunAsync(
            new TrackMetadataBackfillRequest(false, null, 10));

        context.ChangeTracker.Clear();
        var persisted = await context.Tracks.SingleAsync();
        Assert.Equal("covers/admin/manual.jpg", persisted.CoverUrl);
        Assert.Equal($"lyrics/{track.Id}/lyrics.lrc", persisted.LyricsUrl);
        Assert.Equal(1, first.UpdatedCount);
        Assert.Equal(0, second.CandidateCount);
        Assert.Equal(uploadCount, fixture.Storage.Uploads.Count);
        Assert.DoesNotContain(fixture.Storage.Uploads, path => path.StartsWith("covers/"));
    }

    [Fact]
    public async Task RunAsync_ConcurrentAdministratorReferenceWinsAndUnusedObjectIsDeleted()
    {
        await using var context = CreateContext();
        var track = Track(FirstId);
        track.LyricsUrl = "lyrics/admin/manual.lrc";
        context.Tracks.Add(track);
        await context.SaveChangesAsync();
        var fixture = CreateFixture(context, MetadataWithAssets());
        fixture.Storage.AfterUploadAsync = async path =>
        {
            if (!path.StartsWith("covers/", StringComparison.Ordinal)) return;
            var current = await context.Tracks.SingleAsync(candidate => candidate.Id == track.Id);
            current.CoverUrl = "covers/admin/concurrent.jpg";
            await context.SaveChangesAsync();
        };

        var response = await fixture.Service.RunAsync(
            new TrackMetadataBackfillRequest(false, null, 10));

        context.ChangeTracker.Clear();
        Assert.Equal(
            "covers/admin/concurrent.jpg",
            (await context.Tracks.SingleAsync()).CoverUrl);
        Assert.Equal(0, response.UpdatedCount);
        Assert.Equal([$"covers/{track.Id}/cover.jpg"], fixture.Storage.Deletes);
    }

    [Fact]
    public async Task RunAsync_UnsupportedLyricsRemainMissingWithoutFailingThePage()
    {
        await using var context = CreateContext();
        var track = Track(FirstId);
        track.CoverUrl = "covers/admin/manual.jpg";
        context.Tracks.Add(track);
        await context.SaveChangesAsync();
        var fixture = CreateFixture(context, MetadataWithAssets() with
        {
            CoverData = null,
            CoverContentType = null,
            TimedLyrics = "plain unsynchronized text"
        });

        var response = await fixture.Service.RunAsync(
            new TrackMetadataBackfillRequest(false, null, 10));

        var entry = Assert.Single(response.Entries);
        Assert.Equal("noSupportedAssets", entry.Status);
        Assert.Equal(0, response.FailedCount);
        Assert.Empty(fixture.Storage.Uploads);
        context.ChangeTracker.Clear();
        Assert.Null((await context.Tracks.SingleAsync()).LyricsUrl);
    }

    [Fact]
    public async Task RunAsync_IsolatesFailuresAndDeletesTemporaryFiles()
    {
        using var temporaryDirectory = new TemporaryDirectory();
        await using var context = CreateContext();
        context.Tracks.AddRange(Track(FirstId), Track(SecondId), Track(ThirdId));
        await context.SaveChangesAsync();
        var storage = new BackfillStorage();
        storage.Objects.Remove($"tracks/{FirstId}/audio.mp3");
        var extractor = new BackfillExtractor(MetadataWithAssets())
        {
            FailureFileName = $"{SecondId}.mp3"
        };
        var createdPaths = new List<string>();
        var service = CreateService(
            context,
            storage,
            extractor,
            () =>
            {
                var path = Path.Combine(temporaryDirectory.Path, $"{Guid.NewGuid():N}.tmp");
                createdPaths.Add(path);
                return path;
            });

        var response = await service.RunAsync(
            new TrackMetadataBackfillRequest(true, null, 10));

        Assert.Equal(3, response.CandidateCount);
        Assert.Equal(2, response.FailedCount);
        Assert.Contains(response.Entries, entry => entry.ErrorCode == "AUDIO_NOT_FOUND");
        Assert.Contains(response.Entries, entry => entry.ErrorCode == "EXTRACTION_FAILED");
        Assert.Contains(response.Entries, entry => entry.TrackId == ThirdId && entry.CoverAvailable);
        Assert.All(createdPaths, path => Assert.False(File.Exists(path)));
    }

    private static BackfillFixture CreateFixture(
        FollowDbContext context,
        AudioMetadata? metadata = null)
    {
        var storage = new BackfillStorage();
        var service = CreateService(
            context,
            storage,
            new BackfillExtractor(metadata ?? MetadataWithAssets()));
        return new BackfillFixture(service, storage);
    }

    private static TrackMetadataBackfillService CreateService(
        FollowDbContext context,
        BackfillStorage storage,
        IAudioMetadataExtractor extractor,
        Func<string>? temporaryPathFactory = null) => new(
            context,
            storage,
            extractor,
            new EmbeddedTrackAssetWriter(storage),
            new StorageDeletionQueue(context),
            temporaryPathFactory);

    private static AudioMetadata MetadataWithAssets() => new(
        "Track",
        null,
        null,
        1,
        128,
        "mp3",
        [1, 2, 3],
        "image/jpeg",
        "[00:01.20]line");

    private static Track Track(Guid id) => new()
    {
        Id = id,
        Title = $"Track {id}",
        FilePath = $"tracks/{id}/audio.mp3",
        OriginalFileName = $"{id}.mp3"
    };

    private static FollowDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

    private sealed record BackfillFixture(
        TrackMetadataBackfillService Service,
        BackfillStorage Storage);

    private sealed class BackfillExtractor : IAudioMetadataExtractor
    {
        private readonly AudioMetadata _metadata;

        public BackfillExtractor(AudioMetadata metadata)
        {
            _metadata = metadata;
        }

        public string? FailureFileName { get; init; }

        public Task<AudioMetadata> ExtractAsync(
            Stream source,
            string fileName,
            CancellationToken cancellationToken = default)
        {
            if (fileName == FailureFileName)
                throw new InvalidDataException("simulated extraction failure");
            return Task.FromResult(_metadata);
        }
    }

    private sealed class BackfillStorage : IStorageService
    {
        public Dictionary<string, byte[]> Objects { get; } = Enumerable.Range(1, 3)
            .ToDictionary(
                index => $"tracks/00000000-0000-0000-0000-{index:D12}/audio.mp3",
                _ => new byte[] { 1 });
        public List<string> Uploads { get; } = [];
        public List<string> Deletes { get; } = [];
        public Func<string, Task>? AfterUploadAsync { get; set; }

        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(
            string filePath,
            CancellationToken cancellationToken = default) => Task.FromResult(
                Objects.TryGetValue(filePath, out var bytes)
                    ? new StorageObjectMetadata(bytes.Length, "audio/mpeg", null)
                    : null);

        public async Task CopyRangeToAsync(
            string filePath,
            long offset,
            long length,
            Stream destination,
            CancellationToken cancellationToken = default)
        {
            var bytes = Objects[filePath];
            await destination.WriteAsync(
                bytes.AsMemory((int)offset, (int)length),
                cancellationToken);
        }

        public async Task<string> UploadFileAsync(
            Stream fileStream,
            string fileName,
            string contentType,
            string? folder = null)
        {
            var path = $"{folder}/{fileName}";
            Uploads.Add(path);
            if (AfterUploadAsync != null) await AfterUploadAsync(path);
            return path;
        }

        public Task<bool> DeleteFileAsync(string filePath)
        {
            Deletes.Add(filePath);
            return Task.FromResult(true);
        }

        public Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default) => throw new NotSupportedException();
    }
}
