using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging.Abstractions;

namespace Follow.Api.Tests;

public class TrackStorageConsistencyTests
{
    [Theory]
    [InlineData("../../song.mp3", "song.mp3")]
    [InlineData("..\\..\\cover.jpg", "cover.jpg")]
    [InlineData("folder/song.flac", "song.flac")]
    public void StorageUpload_NormalizesUntrustedFileName(
        string supplied,
        string expected)
    {
        Assert.Equal(expected, MinioStorageService.NormalizeFileName(supplied));
    }

    [Fact]
    public async Task RangeCopy_CopiesExactlyRequestedBytes()
    {
        var sourceBytes = Enumerable.Range(0, 32).Select(value => (byte)value).ToArray();
        await using var source = new MemoryStream(sourceBytes);
        await using var destination = new MemoryStream();

        await MinioStorageService.CopyExactlyAsync(
            source,
            destination,
            length: 16,
            CancellationToken.None);

        Assert.Equal(sourceBytes[..16], destination.ToArray());
        Assert.Equal(16, source.Position);
    }

    [Fact]
    public async Task RangeCopy_RejectsUnexpectedlyShortStorageResponse()
    {
        await using var source = new MemoryStream([1, 2, 3]);
        await using var destination = new MemoryStream();

        await Assert.ThrowsAsync<EndOfStreamException>(() =>
            MinioStorageService.CopyExactlyAsync(
                source,
                destination,
                length: 4,
                CancellationToken.None));
    }

    [Fact]
    public void MinioRangeDownload_UsesInternalPresignedHttpRange()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Infrastructure/Services/MinioStorageService.cs"));

        Assert.Contains("PresignedGetObjectAsync", source);
        Assert.Contains("RangeHeaderValue", source);
        Assert.Contains("AllowAutoRedirect = false", source);
        Assert.Contains("ThrowIfCancellationRequested", source);
        Assert.Contains("contentRange?.Unit", source);
        Assert.Contains("_endpointUri", source);
        Assert.DoesNotContain("WithOffsetAndLength", source);
    }

    [Fact]
    public async Task ReplaceTrackCover_SwitchesReferenceAndQueuesOldObject()
    {
        await using var context = CreateContext();
        var track = new Track
        {
            Title = "Track",
            FilePath = "tracks/id/song.mp3",
            CoverUrl = "covers/id/old.jpg"
        };
        context.Tracks.Add(track);
        await context.SaveChangesAsync();
        var storage = new RecordingStorageService("covers/id/new.jpg");
        var service = CreateTrackService(context, storage);

        await service.UploadTrackCoverAsync(
            track.Id,
            new MemoryStream([1, 2, 3]),
            "new.jpg",
            "image/jpeg");

        Assert.Equal("covers/id/new.jpg", (await context.Tracks.SingleAsync()).CoverUrl);
        Assert.Equal(
            "covers/id/old.jpg",
            (await context.StorageDeletionJobs.SingleAsync()).ObjectPath);
        Assert.Empty(storage.DeletedPaths);
    }

    [Fact]
    public async Task DeleteTrack_QueuesAudioCoverAndLyricsWithoutDeletingFirst()
    {
        await using var context = CreateContext();
        var track = new Track
        {
            Title = "Track",
            FilePath = "tracks/id/song.mp3",
            CoverUrl = "covers/id/cover.jpg",
            LyricsUrl = "lyrics/id/song.lrc"
        };
        context.Tracks.Add(track);
        await context.SaveChangesAsync();
        var storage = new RecordingStorageService("unused");
        var service = CreateTrackService(context, storage);

        Assert.True(await service.DeleteTrackAsync(track.Id));

        Assert.Empty(await context.Tracks.ToListAsync());
        Assert.Equal(
            ["covers/id/cover.jpg", "lyrics/id/song.lrc", "tracks/id/song.mp3"],
            await context.StorageDeletionJobs
                .OrderBy(job => job.ObjectPath)
                .Select(job => job.ObjectPath)
                .ToListAsync());
        Assert.Empty(storage.DeletedPaths);
    }

    [Fact]
    public async Task ArtistAndAlbumCoverReplacement_QueueOldObjects()
    {
        await using var context = CreateContext();
        var artist = new Artist { Name = "Artist", CoverUrl = "artists/id/old.jpg" };
        var album = new Album { Title = "Album", CoverUrl = "albums/id/old.jpg" };
        context.AddRange(artist, album);
        await context.SaveChangesAsync();
        var storage = new RecordingStorageService("covers/new.jpg");
        var queue = new StorageDeletionQueue(context);
        var artistService = new ArtistService(
            context,
            storage,
            queue,
            NullLogger<ArtistService>.Instance);
        var albumService = new AlbumService(
            context,
            storage,
            queue,
            NullLogger<AlbumService>.Instance);

        await artistService.UploadArtistCoverAsync(
            artist.Id, new MemoryStream([1]), "new.jpg", "image/jpeg");
        await albumService.UploadAlbumCoverAsync(
            album.Id, new MemoryStream([1]), "new.jpg", "image/jpeg");

        Assert.Equal(2, await context.StorageDeletionJobs.CountAsync());
        Assert.Empty(storage.DeletedPaths);
    }

    [Fact]
    public async Task MetadataHelpers_DoNotPersistBeforeTrackGraphCommit()
    {
        await using var context = CreateContext();
        var storage = new RecordingStorageService("unused");
        var queue = new StorageDeletionQueue(context);
        var artistService = new ArtistService(
            context,
            storage,
            queue,
            NullLogger<ArtistService>.Instance);
        var albumService = new AlbumService(
            context,
            storage,
            queue,
            NullLogger<AlbumService>.Instance);

        var artist = await artistService.GetOrCreateArtistByNameAsync("Artist");
        var album = await albumService.GetOrCreateAlbumAsync("Album", artist!.Id);

        Assert.Equal(EntityState.Added, context.Entry(artist).State);
        Assert.Equal(EntityState.Added, context.Entry(album!).State);
        Assert.Empty(await context.Artists.AsNoTracking().ToListAsync());
        Assert.Empty(await context.Albums.AsNoTracking().ToListAsync());
    }

    [Fact]
    public void ConfirmedApply_UsesExplicitRelationalTransaction()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var source = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Infrastructure/Services/MusicImportApplyService.cs"));

        Assert.Contains("BeginTransactionAsync", source);
        Assert.Contains("CommitAsync", source);
        Assert.Contains("RollbackAsync", source);
    }

    [Fact]
    public async Task ExtractedCover_SaveFailureRestoresReferenceAndDeletesObject()
    {
        var interceptor = new FailNextSaveInterceptor();
        await using var context = CreateContext(interceptor);
        var track = new Track
        {
            Title = "Track",
            FilePath = "tracks/id/song.mp3"
        };
        context.Tracks.Add(track);
        await context.SaveChangesAsync();
        var storage = new RecordingStorageService("unused");
        var service = CreateTrackService(context, storage);
        interceptor.IsArmed = true;

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.PersistExtractedCoverReferenceAsync(
                track,
                "covers/id/extracted.jpg"));

        Assert.Null(track.CoverUrl);
        Assert.Equal(["covers/id/extracted.jpg"], storage.DeletedPaths);
        context.ChangeTracker.Clear();
        Assert.Null((await context.Tracks.SingleAsync()).CoverUrl);
    }

    [Theory]
    [InlineData("track-cover", "covers/id/new.jpg")]
    [InlineData("track-lyrics", "lyrics/id/new.lrc")]
    [InlineData("extracted-cover", "covers/id/new.jpg")]
    [InlineData("artist-cover", "covers/id/new.jpg")]
    [InlineData("album-cover", "covers/id/new.jpg")]
    public async Task MediaReferenceSaveFailureAndDeleteFailureQueuesNewObject(
        string target,
        string uploadedPath)
    {
        var interceptor = new FailNextSaveInterceptor();
        await using var context = CreateContext(interceptor);
        var track = new Track
        {
            Title = "Track",
            FilePath = "tracks/id/song.mp3",
            CoverUrl = "covers/id/old.jpg",
            LyricsUrl = "lyrics/id/old.lrc"
        };
        var artist = new Artist { Name = "Artist", CoverUrl = "artists/id/old.jpg" };
        var album = new Album { Title = "Album", CoverUrl = "albums/id/old.jpg" };
        context.AddRange(track, artist, album);
        await context.SaveChangesAsync();
        var storage = new RecordingStorageService(
            uploadedPath,
            deleteSucceeds: false);
        var queue = new StorageDeletionQueue(context);
        var trackService = CreateTrackService(context, storage);
        interceptor.IsArmed = true;

        await Assert.ThrowsAsync<InvalidOperationException>(() => target switch
        {
            "track-cover" => trackService.UploadTrackCoverAsync(
                track.Id, new MemoryStream([1]), "new.jpg", "image/jpeg"),
            "track-lyrics" => trackService.UploadTrackLyricsAsync(
                track.Id, new MemoryStream([1]), "new.lrc", "text/plain"),
            "extracted-cover" => trackService.PersistExtractedCoverReferenceAsync(
                track, uploadedPath),
            "artist-cover" => new ArtistService(
                    context, storage, queue, NullLogger<ArtistService>.Instance)
                .UploadArtistCoverAsync(
                    artist.Id, new MemoryStream([1]), "new.jpg", "image/jpeg"),
            "album-cover" => new AlbumService(
                    context, storage, queue, NullLogger<AlbumService>.Instance)
                .UploadAlbumCoverAsync(
                    album.Id, new MemoryStream([1]), "new.jpg", "image/jpeg"),
            _ => throw new InvalidOperationException($"Unknown target: {target}")
        });

        context.ChangeTracker.Clear();
        Assert.Equal([uploadedPath], storage.DeletedPaths);
        Assert.Equal(
            uploadedPath,
            (await context.StorageDeletionJobs.SingleAsync()).ObjectPath);
    }

    [Theory]
    [InlineData("artist")]
    [InlineData("album")]
    public async Task CoverUpload_DatabaseFailureDeletesNewObject(string target)
    {
        var interceptor = new FailNextSaveInterceptor();
        await using var context = CreateContext(interceptor);
        var artist = new Artist { Name = "Artist", CoverUrl = "artists/id/old.jpg" };
        var album = new Album { Title = "Album", CoverUrl = "albums/id/old.jpg" };
        context.AddRange(artist, album);
        await context.SaveChangesAsync();
        var storage = new RecordingStorageService("covers/id/new.jpg");
        var queue = new StorageDeletionQueue(context);
        interceptor.IsArmed = true;

        if (target == "artist")
        {
            var service = new ArtistService(
                context, storage, queue, NullLogger<ArtistService>.Instance);
            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                service.UploadArtistCoverAsync(
                    artist.Id, new MemoryStream([1]), "new.jpg", "image/jpeg"));
        }
        else
        {
            var service = new AlbumService(
                context, storage, queue, NullLogger<AlbumService>.Instance);
            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                service.UploadAlbumCoverAsync(
                    album.Id, new MemoryStream([1]), "new.jpg", "image/jpeg"));
        }

        context.ChangeTracker.Clear();
        Assert.Equal(["covers/id/new.jpg"], storage.DeletedPaths);
        Assert.Empty(await context.StorageDeletionJobs.ToListAsync());
        Assert.Equal("artists/id/old.jpg", (await context.Artists.SingleAsync()).CoverUrl);
        Assert.Equal("albums/id/old.jpg", (await context.Albums.SingleAsync()).CoverUrl);
    }

    private static TrackService CreateTrackService(
        FollowDbContext context,
        RecordingStorageService storage)
    {
        var queue = new StorageDeletionQueue(context);
        var artistService = new ArtistService(
            context, storage, queue, NullLogger<ArtistService>.Instance);
        var albumService = new AlbumService(
            context, storage, queue, NullLogger<AlbumService>.Instance);
        return new TrackService(
            context,
            storage,
            artistService,
            albumService,
            queue,
            NullLogger<TrackService>.Instance);
    }

    private static FollowDbContext CreateContext(params IInterceptor[] interceptors)
    {
        var builder = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString());
        if (interceptors.Length > 0) builder.AddInterceptors(interceptors);
        var options = builder.Options;
        return new FollowDbContext(options);
    }

    private sealed class FailNextSaveInterceptor : SaveChangesInterceptor
    {
        public bool IsArmed { get; set; }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            if (!IsArmed) return ValueTask.FromResult(result);
            IsArmed = false;
            throw new InvalidOperationException("simulated database failure");
        }
    }

    private sealed class RecordingStorageService : IStorageService
    {
        private readonly string _uploadedPath;
        private readonly bool _deleteSucceeds;

        public RecordingStorageService(
            string uploadedPath,
            bool deleteSucceeds = true)
        {
            _uploadedPath = uploadedPath;
            _deleteSucceeds = deleteSucceeds;
        }

        public List<string> DeletedPaths { get; } = [];

        public Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default) => throw new NotSupportedException();

        public Task<string> UploadFileAsync(
            Stream fileStream,
            string fileName,
            string contentType,
            string? folder = null) => Task.FromResult(_uploadedPath);

        public Task<bool> DeleteFileAsync(string filePath)
        {
            DeletedPaths.Add(filePath);
            return Task.FromResult(_deleteSucceeds);
        }

        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(
            string filePath,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();

        public Task CopyRangeToAsync(
            string filePath,
            long offset,
            long length,
            Stream destination,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();

    }
}
