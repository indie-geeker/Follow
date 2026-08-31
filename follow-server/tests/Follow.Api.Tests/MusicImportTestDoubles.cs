using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Follow.Api.Tests;

internal sealed class RecordingMetadataExtractor : IAudioMetadataExtractor
{
    private readonly AudioMetadata _metadata;

    public RecordingMetadataExtractor(AudioMetadata metadata) => _metadata = metadata;

    public int CallCount { get; private set; }

    public Task<AudioMetadata> ExtractAsync(
        Stream source,
        string fileName,
        CancellationToken cancellationToken = default)
    {
        CallCount++;
        return Task.FromResult(_metadata);
    }
}

internal sealed class RecordingImportStorageService : IStorageService
{
    public Dictionary<string, byte[]> Objects { get; } = new(StringComparer.Ordinal);
    public List<string> Writes { get; } = [];
    public List<string> Deletes { get; } = [];
    public bool DeleteSucceeds { get; set; } = true;
    public bool ThrowAfterWrite { get; set; }
    public Func<Task>? AfterWriteAsync { get; set; }

    public async Task WriteObjectAsync(
        string objectPath,
        Stream source,
        long length,
        string contentType,
        CancellationToken cancellationToken = default)
    {
        using var buffer = new MemoryStream();
        await source.CopyToAsync(buffer, cancellationToken);
        if (buffer.Length != length) throw new EndOfStreamException();
        Writes.Add(objectPath);
        Objects[objectPath] = buffer.ToArray();
        if (AfterWriteAsync != null) await AfterWriteAsync();
        if (ThrowAfterWrite) throw new IOException("Forced object write failure.");
    }

    public Task<string> UploadFileAsync(
        Stream fileStream,
        string fileName,
        string contentType,
        string? folder = null) => throw new NotSupportedException();

    public Task<StorageObjectMetadata?> GetObjectMetadataAsync(
        string filePath,
        CancellationToken cancellationToken = default) =>
        Task.FromResult(Objects.TryGetValue(filePath, out var bytes)
            ? new StorageObjectMetadata(bytes.LongLength, "audio/mpeg", null)
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

    public Task<bool> DeleteFileAsync(string filePath)
    {
        Deletes.Add(filePath);
        if (DeleteSucceeds) Objects.Remove(filePath);
        return Task.FromResult(DeleteSucceeds);
    }
}

internal sealed class FailNextTrackSaveContext : FollowDbContext
{
    public FailNextTrackSaveContext(DbContextOptions<FollowDbContext> options) : base(options)
    {
    }

    public bool FailNextTrackSave { get; set; }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        if (FailNextTrackSave &&
            ChangeTracker.Entries<Track>().Any(entry => entry.State == EntityState.Added))
        {
            FailNextTrackSave = false;
            throw new InvalidOperationException("Forced database failure.");
        }

        return base.SaveChangesAsync(cancellationToken);
    }
}
