namespace Follow.Core.Interfaces;

public interface IAudioMetadataExtractor
{
    Task<AudioMetadata> ExtractAsync(
        Stream source,
        string fileName,
        CancellationToken cancellationToken = default);
}

public sealed record AudioMetadata(
    string Title,
    string? Artist,
    string? Album,
    int DurationSeconds,
    int BitRate,
    string Format,
    byte[]? CoverData = null,
    string? CoverContentType = null,
    string? TimedLyrics = null);
