using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Follow.Api.Tests;

public class StorageDeletionWorkerTests
{
    [Fact]
    public void Queue_RejectsUnmanagedObjectPath()
    {
        using var context = CreateContext();
        var queue = new StorageDeletionQueue(context);

        Assert.Throws<ArgumentException>(() => queue.Enqueue("https://example.com/cover.jpg"));
        Assert.Throws<ArgumentException>(() => queue.Enqueue("../tracks/song.mp3"));
    }

    [Fact]
    public async Task Processor_RetriesFailureAndCompletesLater()
    {
        await using var context = CreateContext();
        context.StorageDeletionJobs.Add(new StorageDeletionJob
        {
            ObjectPath = "tracks/id/song.mp3",
            NextAttemptAt = DateTime.UtcNow.AddMinutes(-1)
        });
        await context.SaveChangesAsync();
        var storage = new SequencedDeleteStorageService(false, true);
        var now = DateTime.UtcNow;

        await StorageDeletionWorker.ProcessPendingAsync(
            context, storage, now, NullLogger.Instance);

        var failed = await context.StorageDeletionJobs.SingleAsync();
        Assert.Equal(1, failed.AttemptCount);
        Assert.Null(failed.CompletedAt);
        Assert.True(failed.NextAttemptAt > now);

        await StorageDeletionWorker.ProcessPendingAsync(
            context,
            storage,
            failed.NextAttemptAt.AddSeconds(1),
            NullLogger.Instance);

        Assert.NotNull((await context.StorageDeletionJobs.SingleAsync()).CompletedAt);
    }

    [Fact]
    public async Task Processor_UpdatesReplacementRevisionCleanupState()
    {
        await using var context = CreateContext();
        var user = new User
        {
            Username = "cleanup-admin",
            Email = "cleanup@example.test",
            PasswordHash = "test"
        };
        var track = new Track { Title = "track", FilePath = "tracks/new/audio.flac" };
        var batch = new MusicImportBatch
        {
            RequestedByUser = user,
            RequestedByUserId = user.Id,
            ClientRequestId = "cleanup",
            Status = MusicImportBatchStatus.Completed
        };
        var group = new MusicImportReviewGroup
        {
            Batch = batch,
            BatchId = batch.Id,
            Status = MusicImportReviewStatus.Applied
        };
        var job = new StorageDeletionJob
        {
            ObjectPath = "tracks/old/audio.mp3",
            NextAttemptAt = DateTime.UtcNow.AddMinutes(-1)
        };
        var revision = new TrackAudioRevision
        {
            Track = track,
            TrackId = track.Id,
            ReviewGroup = group,
            ReviewGroupId = group.Id,
            ActingUser = user,
            ActingUserId = user.Id,
            PreviousObjectPath = job.ObjectPath,
            ReplacementObjectPath = track.FilePath,
            StorageDeletionJob = job,
            StorageDeletionJobId = job.Id,
            CleanupStatus = TrackAudioRevisionCleanupStatus.Pending
        };
        context.AddRange(user, track, batch, group, job, revision);
        await context.SaveChangesAsync();

        await StorageDeletionWorker.ProcessPendingAsync(
            context,
            new SequencedDeleteStorageService(true),
            DateTime.UtcNow,
            NullLogger.Instance);

        Assert.Equal(
            TrackAudioRevisionCleanupStatus.Completed,
            (await context.TrackAudioRevisions.SingleAsync()).CleanupStatus);
    }

    private static FollowDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FollowDbContext(options);
    }

    private sealed class SequencedDeleteStorageService : IStorageService
    {
        private readonly Queue<bool> _results;

        public SequencedDeleteStorageService(params bool[] results)
        {
            _results = new Queue<bool>(results);
        }

        public Task<bool> DeleteFileAsync(string filePath) =>
            Task.FromResult(_results.Dequeue());

        public Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default) => throw new NotSupportedException();

        public Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null) => throw new NotSupportedException();
        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) => throw new NotSupportedException();
    }
}
