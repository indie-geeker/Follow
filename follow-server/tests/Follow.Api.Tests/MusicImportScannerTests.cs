using Follow.Core.Entities;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

public class MusicImportScannerTests
{
    [Fact]
    public async Task Scan_RecursivelyPersistsSupportedFilesAndDurableTotals()
    {
        using var source = new TemporaryDirectory();
        var selected = Directory.CreateDirectory(Path.Combine(source.Path, "selected"));
        var nested = Directory.CreateDirectory(Path.Combine(selected.FullName, "nested"));
        await File.WriteAllBytesAsync(Path.Combine(selected.FullName, "first.MP3"), [1, 2, 3]);
        await File.WriteAllBytesAsync(Path.Combine(nested.FullName, "second.flac"), [4, 5]);
        await File.WriteAllTextAsync(Path.Combine(selected.FullName, "notes.txt"), "ignored");

        await using var context = CreateContext();
        var batch = AddBatch(context, "selected");
        await context.SaveChangesAsync();

        var scanner = new MusicImportScanner(context, EnabledSettings(source.Path));
        await scanner.ScanAsync(batch.Id);

        var items = await context.MusicImportItems
            .OrderBy(item => item.RelativePath)
            .ToListAsync();
        Assert.Collection(
            items,
            item =>
            {
                Assert.Equal("selected/first.MP3", item.RelativePath);
                Assert.Equal("first.MP3", item.OriginalFileName);
                Assert.Equal(".mp3", item.Extension);
                Assert.Equal(3, item.SizeBytes);
                Assert.NotEqual(default, item.SourceModifiedAt);
            },
            item =>
            {
                Assert.Equal("selected/nested/second.flac", item.RelativePath);
                Assert.Equal(2, item.SizeBytes);
            });
        Assert.Equal(MusicImportBatchStatus.Ready, batch.Status);
        Assert.Equal(2, batch.DiscoveredFileCount);
        Assert.Equal(1, batch.IgnoredFileCount);
        Assert.Equal(5, batch.TotalBytes);
        Assert.NotNull(batch.ScanCompletedAt);
    }

    [Fact]
    public async Task Scan_RestartDoesNotDuplicateItemsOrTotals()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "once.mp3"), [1, 2, 3, 4]);

        await using var context = CreateContext();
        var batch = AddBatch(context);
        await context.SaveChangesAsync();
        var scanner = new MusicImportScanner(context, EnabledSettings(source.Path));

        await scanner.ScanAsync(batch.Id);
        batch.Status = MusicImportBatchStatus.Scanning;
        batch.ScanCompletedAt = null;
        await context.SaveChangesAsync();
        await scanner.ScanAsync(batch.Id);

        Assert.Equal(1, await context.MusicImportItems.CountAsync());
        Assert.Equal(1, batch.DiscoveredFileCount);
        Assert.Equal(4, batch.TotalBytes);
    }

    [Fact]
    public async Task Scan_HonorsCancellationWithoutMarkingBatchReady()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "cancel.mp3"), [1]);
        await using var context = CreateContext();
        var batch = AddBatch(context);
        await context.SaveChangesAsync();
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        var scanner = new MusicImportScanner(context, EnabledSettings(source.Path));
        await Assert.ThrowsAnyAsync<OperationCanceledException>(
            () => scanner.ScanAsync(batch.Id, cancellation.Token));

        Assert.Equal(MusicImportBatchStatus.Scanning, batch.Status);
        Assert.Null(batch.ScanCompletedAt);
    }

    [Fact]
    public async Task Scan_DoesNotFollowReparsePointFiles()
    {
        using var source = new TemporaryDirectory();
        using var outside = new TemporaryDirectory();
        var target = Path.Combine(outside.Path, "outside.mp3");
        await File.WriteAllBytesAsync(target, [9, 9, 9]);
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "inside.mp3"), [1]);
        File.CreateSymbolicLink(Path.Combine(source.Path, "linked.mp3"), target);

        await using var context = CreateContext();
        var batch = AddBatch(context);
        await context.SaveChangesAsync();

        var scanner = new MusicImportScanner(context, EnabledSettings(source.Path));
        await scanner.ScanAsync(batch.Id);

        var item = Assert.Single(await context.MusicImportItems.ToListAsync());
        Assert.Equal("inside.mp3", item.RelativePath);
        Assert.Equal(1, batch.IgnoredFileCount);
    }

    [Fact]
    public async Task Scan_DoesNotFollowReparsePointDirectories()
    {
        using var source = new TemporaryDirectory();
        using var outside = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(outside.Path, "outside.mp3"), [9]);
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "inside.mp3"), [1]);
        Directory.CreateSymbolicLink(Path.Combine(source.Path, "linked-directory"), outside.Path);

        await using var context = CreateContext();
        var batch = AddBatch(context);
        await context.SaveChangesAsync();

        var scanner = new MusicImportScanner(context, EnabledSettings(source.Path));
        await scanner.ScanAsync(batch.Id);

        Assert.Equal("inside.mp3", Assert.Single(await context.MusicImportItems.ToListAsync()).RelativePath);
        Assert.Equal(1, batch.IgnoredFileCount);
    }

    [Fact]
    public async Task Scan_DetachesPersistedChunksSoTrackingMemoryIsBounded()
    {
        using var source = new TemporaryDirectory();
        for (var index = 0; index < 7; index++)
            await File.WriteAllBytesAsync(Path.Combine(source.Path, $"{index}.mp3"), [1]);

        await using var context = CreateContext();
        var batch = AddBatch(context);
        await context.SaveChangesAsync();
        var scanner = new MusicImportScanner(context, EnabledSettings(source.Path));

        await scanner.ScanAsync(batch.Id);

        Assert.Empty(context.ChangeTracker.Entries<MusicImportItem>());
        Assert.Equal(7, batch.DiscoveredFileCount);
    }

    [Fact]
    public async Task Scan_StopsCleanlyWhenPersistedCancelIsObservedBetweenChunks()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "a.mp3"), [1]);
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "b.mp3"), [2]);
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        Guid batchId;
        await using (var seed = new FollowDbContext(options))
        {
            var batch = AddBatch(seed);
            batchId = batch.Id;
            await seed.SaveChangesAsync();
        }

        await using var context = new CancelAfterFirstItemContext(options, batchId);
        var settings = WithScanBatchSize(EnabledSettings(source.Path), 1);
        var scanner = new MusicImportScanner(context, settings);

        await scanner.ScanAsync(batchId);

        var batchAfterCancel = await context.MusicImportBatches.AsNoTracking()
            .SingleAsync(batch => batch.Id == batchId);
        Assert.Equal(MusicImportBatchStatus.CancelRequested, batchAfterCancel.Status);
        Assert.Null(batchAfterCancel.ScanCompletedAt);
    }

    [Fact]
    public async Task OwnedScan_ObservedCancel_ReleasesLeaseBeforeReturning()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "a.mp3"), [1]);
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "b.mp3"), [2]);
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        Guid batchId;
        await using (var seed = new FollowDbContext(options))
        {
            var batch = AddBatch(seed);
            batch.LeaseOwner = "scan-owner";
            batch.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(10);
            batchId = batch.Id;
            await seed.SaveChangesAsync();
        }

        await using var context = new CancelAfterFirstItemContext(options, batchId);
        var scanner = new MusicImportScanner(
            context,
            WithScanBatchSize(EnabledSettings(source.Path), 1));

        await scanner.ScanAsync(batchId, "scan-owner");

        await using var verify = new FollowDbContext(options);
        var batchAfterCancel = await verify.MusicImportBatches
            .SingleAsync(batch => batch.Id == batchId);
        Assert.Equal(MusicImportBatchStatus.CancelRequested, batchAfterCancel.Status);
        Assert.Null(batchAfterCancel.LeaseOwner);
        Assert.Null(batchAfterCancel.LeaseExpiresAt);
        Assert.Null(batchAfterCancel.ScanCompletedAt);
    }

    [Fact]
    public async Task Scan_ConcurrentCancelBeforeChunkCommit_RollsBackTheChunk()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "race.mp3"), [1]);
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        Guid batchId;
        await using (var seed = new FollowDbContext(options))
        {
            var batch = AddBatch(seed);
            batch.LeaseOwner = "scan-owner";
            batch.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(10);
            batchId = batch.Id;
            await seed.SaveChangesAsync();
        }

        await using var context = new CancelBeforeFirstItemSaveContext(options, batchId);
        var scanner = new MusicImportScanner(
            context,
            WithScanBatchSize(EnabledSettings(source.Path), 1));

        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() =>
            scanner.ScanAsync(batchId, "scan-owner"));

        await using var verify = new FollowDbContext(options);
        Assert.Equal(
            MusicImportBatchStatus.CancelRequested,
            (await verify.MusicImportBatches.SingleAsync()).Status);
        Assert.Empty(await verify.MusicImportItems.ToListAsync());
    }

    [Fact]
    public async Task Scan_RenewsAndValidatesOwnedBatchLease()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "lease.mp3"), [1]);
        await using var context = CreateContext();
        var batch = AddBatch(context);
        batch.LeaseOwner = "scan-owner";
        batch.LeaseExpiresAt = DateTime.UtcNow.AddSeconds(5);
        var originalExpiry = batch.LeaseExpiresAt;
        await context.SaveChangesAsync();

        var scanner = new MusicImportScanner(context, EnabledSettings(source.Path));
        await scanner.ScanAsync(batch.Id, "scan-owner");

        Assert.Equal(MusicImportBatchStatus.Ready, batch.Status);
        Assert.True(batch.LeaseExpiresAt > originalExpiry);
    }

    [Fact]
    public async Task Scan_LostLeaseCannotFinalizeBatchReady()
    {
        using var source = new TemporaryDirectory();
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "a.mp3"), [1]);
        await File.WriteAllBytesAsync(Path.Combine(source.Path, "b.mp3"), [2]);
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        Guid batchId;
        await using (var seed = new FollowDbContext(options))
        {
            var batch = AddBatch(seed);
            batch.LeaseOwner = "original-owner";
            batch.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(10);
            batchId = batch.Id;
            await seed.SaveChangesAsync();
        }

        await using var context = new StealScanLeaseAfterFirstItemContext(options, batchId);
        var scanner = new MusicImportScanner(
            context,
            WithScanBatchSize(EnabledSettings(source.Path), 1));

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            scanner.ScanAsync(batchId, "original-owner"));

        await using var verify = new FollowDbContext(options);
        var batchAfterLoss = await verify.MusicImportBatches.SingleAsync(
            batch => batch.Id == batchId);
        Assert.Equal(MusicImportBatchStatus.Scanning, batchAfterLoss.Status);
        Assert.Equal("new-owner", batchAfterLoss.LeaseOwner);
    }

    [Fact]
    public async Task Scan_RenewsOwnedLeaseAcrossLargeFlatIgnoredDirectory()
    {
        using var source = new TemporaryDirectory();
        for (var index = 0; index < 10; index++)
            await File.WriteAllTextAsync(Path.Combine(source.Path, $"ignored-{index}.txt"), "x");
        await using var context = CreateContext();
        var batch = AddBatch(context);
        batch.LeaseOwner = "flat-scan-owner";
        batch.LeaseExpiresAt = DateTime.UtcNow.AddSeconds(2);
        await context.SaveChangesAsync();
        var settings = new MusicImportRuntimeSettings
        {
            Enabled = true,
            SourceRoot = source.Path,
            ScanBatchSize = 2,
            MaximumFileBytes = 1024,
            LeaseDuration = TimeSpan.FromSeconds(2)
        };
        var scanner = new MusicImportScanner(context, settings);

        await scanner.ScanAsync(batch.Id, "flat-scan-owner");

        Assert.Equal(10, batch.IgnoredFileCount);
        Assert.True(batch.Version >= 8, $"Expected entry-level lease renewals, got version {batch.Version}.");
    }

    internal static MusicImportRuntimeSettings EnabledSettings(string sourceRoot) => new()
    {
        Enabled = true,
        SourceRoot = sourceRoot,
        ScanBatchSize = 2,
        MaximumFileBytes = 1024
    };

    private static MusicImportRuntimeSettings WithScanBatchSize(
        MusicImportRuntimeSettings settings,
        int scanBatchSize) => new()
    {
        Enabled = settings.Enabled,
        SourceRoot = settings.SourceRoot,
        SourceAlias = settings.SourceAlias,
        MaximumFileBytes = settings.MaximumFileBytes,
        MaximumRelativePathLength = settings.MaximumRelativePathLength,
        ScanBatchSize = scanBatchSize,
        ProcessingConcurrency = settings.ProcessingConcurrency,
        LeaseDuration = settings.LeaseDuration
    };

    internal static FollowDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new FollowDbContext(options);
    }

    internal static MusicImportBatch AddBatch(
        FollowDbContext context,
        string relativeDirectory = "")
    {
        var batch = new MusicImportBatch
        {
            RequestedByUserId = Guid.NewGuid(),
            ClientRequestId = Guid.NewGuid().ToString("N"),
            RelativeDirectory = relativeDirectory,
            Status = MusicImportBatchStatus.Scanning,
            ScanStartedAt = DateTime.UtcNow
        };
        context.MusicImportBatches.Add(batch);
        return batch;
    }
}

internal sealed class CancelAfterFirstItemContext : FollowDbContext
{
    private readonly DbContextOptions<FollowDbContext> _options;
    private readonly Guid _batchId;
    private bool _cancelled;

    public CancelAfterFirstItemContext(
        DbContextOptions<FollowDbContext> options,
        Guid batchId) : base(options)
    {
        _options = options;
        _batchId = batchId;
    }

    public override async Task<int> SaveChangesAsync(
        CancellationToken cancellationToken = default)
    {
        var cancelAfterSave = !_cancelled &&
            ChangeTracker.Entries<MusicImportItem>()
                .Any(entry => entry.State == EntityState.Added);
        var result = await base.SaveChangesAsync(cancellationToken);
        if (!cancelAfterSave) return result;

        _cancelled = true;
        await using var peer = new FollowDbContext(_options);
        var batch = await peer.MusicImportBatches.SingleAsync(
            candidate => candidate.Id == _batchId,
            cancellationToken);
        batch.Status = MusicImportBatchStatus.CancelRequested;
        batch.CancelRequestedAt = DateTime.UtcNow;
        await peer.SaveChangesAsync(cancellationToken);
        return result;
    }
}

internal sealed class StealScanLeaseAfterFirstItemContext : FollowDbContext
{
    private readonly DbContextOptions<FollowDbContext> _options;
    private readonly Guid _batchId;
    private bool _stolen;

    public StealScanLeaseAfterFirstItemContext(
        DbContextOptions<FollowDbContext> options,
        Guid batchId) : base(options)
    {
        _options = options;
        _batchId = batchId;
    }

    public override async Task<int> SaveChangesAsync(
        CancellationToken cancellationToken = default)
    {
        var stealAfterSave = !_stolen &&
            ChangeTracker.Entries<MusicImportItem>()
                .Any(entry => entry.State == EntityState.Added);
        var result = await base.SaveChangesAsync(cancellationToken);
        if (!stealAfterSave) return result;

        _stolen = true;
        await using var peer = new FollowDbContext(_options);
        var batch = await peer.MusicImportBatches.SingleAsync(
            candidate => candidate.Id == _batchId,
            cancellationToken);
        batch.LeaseOwner = "new-owner";
        batch.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(10);
        await peer.SaveChangesAsync(cancellationToken);
        return result;
    }
}

internal sealed class CancelBeforeFirstItemSaveContext : FollowDbContext
{
    private readonly DbContextOptions<FollowDbContext> _options;
    private readonly Guid _batchId;
    private bool _cancelled;

    public CancelBeforeFirstItemSaveContext(
        DbContextOptions<FollowDbContext> options,
        Guid batchId) : base(options)
    {
        _options = options;
        _batchId = batchId;
    }

    public override async Task<int> SaveChangesAsync(
        CancellationToken cancellationToken = default)
    {
        var cancelBeforeSave = !_cancelled &&
            ChangeTracker.Entries<MusicImportItem>()
                .Any(entry => entry.State == EntityState.Added);
        if (cancelBeforeSave)
        {
            _cancelled = true;
            await using var peer = new FollowDbContext(_options);
            var batch = await peer.MusicImportBatches.SingleAsync(
                candidate => candidate.Id == _batchId,
                cancellationToken);
            batch.Status = MusicImportBatchStatus.CancelRequested;
            batch.CancelRequestedAt = DateTime.UtcNow;
            await peer.SaveChangesAsync(cancellationToken);
        }

        return await base.SaveChangesAsync(cancellationToken);
    }
}

internal sealed class TemporaryDirectory : IDisposable
{
    public TemporaryDirectory()
    {
        Path = System.IO.Path.Combine(
            System.IO.Path.GetTempPath(),
            $"follow-import-tests-{Guid.NewGuid():N}");
        Directory.CreateDirectory(Path);
    }

    public string Path { get; }

    public void Dispose()
    {
        if (Directory.Exists(Path)) Directory.Delete(Path, recursive: true);
    }
}
