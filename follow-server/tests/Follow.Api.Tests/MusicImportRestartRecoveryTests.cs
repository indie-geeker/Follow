using Follow.Api.Tests.Infrastructure;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace Follow.Api.Tests;

public sealed class MusicImportRestartRecoveryTests
{
    [Fact]
    public async Task PostgreSqlAndMinio_RacingBrowserUploadsLeaveOneBatchAndCleanLoserObject()
    {
        await using var stack = await DisposableMusicImportStack.CreateAsync();
        Guid userId;
        await using (var seed = stack.CreateContext())
        {
            var user = Admin();
            seed.Users.Add(user);
            await seed.SaveChangesAsync();
            userId = user.Id;
        }
        using var barrier = new Barrier(2);
        var racingStorage = new BarrierStorage(stack.Storage, barrier);
        var first = UploadAsync(stack, racingStorage, userId);
        var second = UploadAsync(stack, racingStorage, userId);

        var outcomes = await Task.WhenAll(first, second);

        Assert.Single(outcomes, outcome => outcome == "success");
        Assert.Single(outcomes, outcome => outcome == "conflict");
        await using var verify = stack.CreateContext();
        Assert.Single(await verify.MusicImportBatches.ToListAsync());
        Assert.Single(await verify.MusicImportItems.ToListAsync());
        Assert.Equal(2, stack.Storage.WrittenObjectPaths.Count);
        var remaining = 0;
        foreach (var objectPath in stack.Storage.WrittenObjectPaths)
        {
            if (await stack.Storage.GetObjectMetadataAsync(objectPath) != null)
                remaining++;
        }
        Assert.Equal(1, remaining);
    }

    [Fact]
    public async Task PostgreSql_NewWorkerRecoversExpiredPartialAnalysisWithoutDuplicateItems()
    {
        await using var stack = await DisposableMusicImportStack.CreateAsync();
        var bytes = Enumerable.Repeat((byte)71, 1024).ToArray();
        var name = "restart.flac";
        var path = Path.Combine(stack.SourceDirectory, name);
        await File.WriteAllBytesAsync(path, bytes);
        stack.SealSourceDirectoryReadOnly();
        Guid itemId;
        await using (var seed = stack.CreateContext())
        {
            var user = Admin();
            var batch = new MusicImportBatch
            {
                RequestedByUser = user,
                RequestedByUserId = user.Id,
                ClientRequestId = Guid.NewGuid().ToString("N"),
                SourceKind = MusicImportSourceKind.MountedDirectory,
                Status = MusicImportBatchStatus.Analyzing
            };
            var item = new MusicImportItem
            {
                Batch = batch,
                BatchId = batch.Id,
                SourceKind = MusicImportSourceKind.MountedDirectory,
                SourceReference = name,
                RelativePath = name,
                OriginalFileName = name,
                Extension = ".flac",
                SizeBytes = bytes.LongLength,
                SourceModifiedAt = MusicImportScanner.NormalizeDatabaseTimestamp(File.GetLastWriteTimeUtc(path)),
                Status = MusicImportItemStatus.Processing,
                Stage = MusicImportItemStage.Hashing,
                LeaseOwner = "dead-worker",
                LeaseExpiresAt = DateTime.UtcNow.AddMinutes(-1),
                AttemptCount = 1
            };
            seed.AddRange(user, batch, item);
            await seed.SaveChangesAsync();
            itemId = item.Id;
        }

        await using var provider = BuildWorkerProvider(stack);
        var firstWorker = Worker(provider, "recovery-worker");
        Assert.True(await firstWorker.RunIterationAsync());
        var restartedWorker = Worker(provider, "replacement-worker");
        Assert.True(await restartedWorker.RunIterationAsync());

        await using var verify = stack.CreateContext();
        var recovered = await verify.MusicImportItems.SingleAsync(item => item.Id == itemId);
        Assert.Equal(MusicImportItemStage.Analyzed, recovered.Stage);
        Assert.Equal(MusicImportItemStatus.Pending, recovered.Status);
        Assert.Equal(2, recovered.AttemptCount);
        Assert.Null(recovered.LeaseOwner);
        Assert.Single(await verify.MusicImportItems.ToListAsync());
        Assert.Empty(await verify.Tracks.ToListAsync());
    }

    [Fact]
    public async Task PostgreSqlAndMinio_CancelledBrowserStagingIsDurablyDeleted()
    {
        await using var stack = await DisposableMusicImportStack.CreateAsync();
        var bytes = Enumerable.Repeat((byte)72, 512).ToArray();
        var itemId = Guid.NewGuid();
        var stagingPath = ImportObjectPath.BuildStaging(itemId, ".mp3");
        await stack.Storage.WriteObjectAsync(
            stagingPath,
            new MemoryStream(bytes),
            bytes.LongLength,
            "audio/mpeg");
        Guid batchId;
        await using (var seed = stack.CreateContext())
        {
            var user = Admin();
            var batch = new MusicImportBatch
            {
                RequestedByUser = user,
                RequestedByUserId = user.Id,
                ClientRequestId = Guid.NewGuid().ToString("N"),
                SourceKind = MusicImportSourceKind.BrowserStaging,
                Status = MusicImportBatchStatus.CancelRequested
            };
            var item = new MusicImportItem
            {
                Id = itemId,
                Batch = batch,
                BatchId = batch.Id,
                SourceKind = MusicImportSourceKind.BrowserStaging,
                SourceReference = stagingPath,
                StagingObjectPath = stagingPath,
                SourceETag = "test-etag",
                RelativePath = $"browser/{itemId:N}/cancel.mp3",
                OriginalFileName = "cancel.mp3",
                Extension = ".mp3",
                SizeBytes = bytes.LongLength,
                Status = MusicImportItemStatus.Pending,
                Stage = MusicImportItemStage.AwaitingReview
            };
            seed.AddRange(user, batch, item);
            await seed.SaveChangesAsync();
            batchId = batch.Id;
        }

        await using var provider = BuildWorkerProvider(stack);
        var worker = Worker(provider, "cancel-worker");
        for (var attempt = 0; attempt < 4; attempt++)
            await worker.RunIterationAsync();

        Assert.Null(await stack.Storage.GetObjectMetadataAsync(stagingPath));
        await using var verify = stack.CreateContext();
        var batchState = await verify.MusicImportBatches.SingleAsync(batch => batch.Id == batchId);
        var itemState = await verify.MusicImportItems.SingleAsync(item => item.Id == itemId);
        Assert.Equal(MusicImportBatchStatus.Cancelled, batchState.Status);
        Assert.Equal(MusicImportItemStatus.Cancelled, itemState.Status);
        Assert.Null(itemState.SourceReference);
        Assert.Null(itemState.StagingObjectPath);
    }

    private static ServiceProvider BuildWorkerProvider(DisposableMusicImportStack stack)
    {
        var settings = new MusicImportRuntimeSettings
        {
            Enabled = true,
            SourceRoot = stack.SourceDirectory,
            MaximumFileBytes = 10_000,
            LeaseDuration = TimeSpan.FromMinutes(2)
        };
        var services = new ServiceCollection();
        services.AddDbContext<FollowDbContext>(options => options.UseNpgsql(stack.ConnectionString));
        services.AddSingleton(settings);
        services.AddSingleton<IStorageService>(stack.Storage);
        services.AddSingleton<IMusicImportSourceReader>(new MusicImportSourceReader(settings, stack.Storage));
        services.AddSingleton<IAudioMetadataExtractor>(new RecordingMetadataExtractor(new AudioMetadata(
            "restart",
            null,
            null,
            60,
            900,
            "flac",
            Codec: "flac",
            Container: "flac",
            IsLossless: true,
            SampleRateHz: 44_100,
            BitDepth: 16,
            Channels: 2,
            BitRateKbps: 900,
            ExactDurationMilliseconds: 60_000)));
        services.AddSingleton<IAudioFingerprintService, MarkerFingerprintService>();
        services.AddScoped<MusicImportAnalysisProcessor>();
        return services.BuildServiceProvider();
    }

    private static MusicImportWorker Worker(ServiceProvider provider, string workerId) => new(
        provider.GetRequiredService<IServiceScopeFactory>(),
        provider.GetRequiredService<MusicImportRuntimeSettings>(),
        NullLogger<MusicImportWorker>.Instance,
        workerId);

    private static async Task<string> UploadAsync(
        DisposableMusicImportStack stack,
        IStorageService storage,
        Guid userId)
    {
        await using var context = stack.CreateContext();
        var service = new MusicImportService(
            context,
            new MusicImportRuntimeSettings
            {
                Enabled = true,
                SourceRoot = stack.SourceDirectory,
                MaximumFileBytes = 10_000
            },
            storage);
        try
        {
            await service.CreateBrowserUploadAsync(
                userId,
                new BrowserMusicImportUpload(
                    new MemoryStream(Enumerable.Repeat((byte)73, 512).ToArray()),
                    "race.mp3",
                    "audio/mpeg",
                    512,
                    "same-browser-request"));
            return "success";
        }
        catch (DbUpdateException)
        {
            return "conflict";
        }
    }

    private static User Admin() => new()
    {
        Username = $"admin-{Guid.NewGuid():N}",
        Email = $"{Guid.NewGuid():N}@example.test",
        PasswordHash = "test",
        Role = UserRole.Admin
    };

    private sealed class MarkerFingerprintService : IAudioFingerprintService
    {
        public Task<AudioFingerprintCapability> CheckCapabilityAsync(CancellationToken cancellationToken = default) =>
            Task.FromResult(new AudioFingerprintCapability(true, "1.6.1", 2, null, null));

        public Task<AudioFingerprint> ExtractAsync(Stream source, TimeSpan sourceDuration, CancellationToken cancellationToken = default)
        {
            var marker = source.ReadByte();
            return Task.FromResult(new AudioFingerprint(
                2,
                "1.6.1",
                sourceDuration,
                Enumerable.Repeat(unchecked((uint)marker), 80).ToArray()));
        }
    }

    private sealed class BarrierStorage(IStorageService inner, Barrier barrier) : IStorageService
    {
        public async Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default)
        {
            await inner.WriteObjectAsync(objectPath, source, length, contentType, cancellationToken);
            if (!barrier.SignalAndWait(TimeSpan.FromSeconds(10), cancellationToken))
                throw new TimeoutException("The upload race barrier timed out.");
        }

        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) =>
            inner.GetObjectMetadataAsync(filePath, cancellationToken);

        public Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) =>
            inner.CopyRangeToAsync(filePath, offset, length, destination, cancellationToken);

        public Task<bool> DeleteFileAsync(string filePath) => inner.DeleteFileAsync(filePath);
        public Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null) =>
            inner.UploadFileAsync(fileStream, fileName, contentType, folder);
    }
}
