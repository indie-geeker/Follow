using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Follow.Infrastructure.Services;

public sealed class StorageDeletionWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<StorageDeletionWorker> _logger;

    public StorageDeletionWorker(
        IServiceScopeFactory scopeFactory,
        ILogger<StorageDeletionWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                var context = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
                var storage = scope.ServiceProvider.GetRequiredService<IStorageService>();
                await ProcessPendingAsync(
                    context,
                    storage,
                    DateTime.UtcNow,
                    _logger,
                    stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Storage deletion worker iteration failed");
            }

            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }
    }

    public static async Task ProcessPendingAsync(
        FollowDbContext context,
        IStorageService storage,
        DateTime now,
        ILogger logger,
        CancellationToken cancellationToken = default)
    {
        var jobs = await context.StorageDeletionJobs
            .Where(job => job.CompletedAt == null && job.NextAttemptAt <= now)
            .OrderBy(job => job.NextAttemptAt)
            .ThenBy(job => job.Id)
            .Take(50)
            .ToListAsync(cancellationToken);

        foreach (var job in jobs)
        {
            var revision = await context.TrackAudioRevisions
                .FirstOrDefaultAsync(
                    candidate => candidate.StorageDeletionJobId == job.Id,
                    cancellationToken);
            try
            {
                if (!StorageDeletionQueue.IsManagedObjectPath(job.ObjectPath))
                    throw new InvalidOperationException("拒绝删除非受管对象路径");

                if (!await storage.DeleteFileAsync(job.ObjectPath))
                    throw new InvalidOperationException("对象存储删除失败");

                job.CompletedAt = now;
                job.LastError = null;
                if (revision != null)
                    revision.CleanupStatus =
                        TrackAudioRevisionCleanupStatus.Completed;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                job.AttemptCount++;
                job.LastError = exception.Message;
                var delaySeconds = Math.Min(3600, 5 * Math.Pow(2, job.AttemptCount - 1));
                job.NextAttemptAt = now.AddSeconds(delaySeconds);
                if (revision != null)
                    revision.CleanupStatus = TrackAudioRevisionCleanupStatus.Failed;
                logger.LogWarning(
                    exception,
                    "Storage deletion job {JobId} failed on attempt {Attempt}",
                    job.Id,
                    job.AttemptCount);
            }
        }

        if (jobs.Count > 0)
            await context.SaveChangesAsync(cancellationToken);
    }
}
