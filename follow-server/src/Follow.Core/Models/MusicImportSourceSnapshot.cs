using Follow.Core.Entities;

namespace Follow.Core.Models;

public sealed record MusicImportSourceSnapshot(
    MusicImportSourceKind Kind,
    string Reference,
    long LengthBytes,
    DateTime? LastModifiedAt,
    string? ETag);

public sealed class MusicImportSourceReadHandle : IAsyncDisposable
{
    private readonly string? _temporaryPath;
    private bool _disposed;

    public MusicImportSourceReadHandle(
        Stream stream,
        MusicImportSourceSnapshot snapshot,
        string? temporaryPath = null)
    {
        Stream = stream;
        Snapshot = snapshot;
        _temporaryPath = temporaryPath;
    }

    public Stream Stream { get; }
    public MusicImportSourceSnapshot Snapshot { get; }

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;
        await Stream.DisposeAsync();
        if (_temporaryPath != null && File.Exists(_temporaryPath))
            File.Delete(_temporaryPath);
    }
}

public sealed class MusicImportSourceChangedException : IOException
{
    public MusicImportSourceChangedException()
        : base("The music import source no longer matches its captured snapshot.")
    {
    }
}

public sealed record BrowserMusicImportUpload(
    Stream Content,
    string FileName,
    string? ContentType,
    long Length,
    string ClientRequestId);
