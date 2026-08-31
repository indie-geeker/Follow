using System.Text;
using Follow.Core.Interfaces;
using Follow.Core.Services;

namespace Follow.Infrastructure.Services;

public sealed record EmbeddedTrackAssetResult(
    string? CoverUrl,
    string? LyricsUrl,
    IReadOnlyList<string> NewObjectPaths);

public sealed class EmbeddedTrackAssetWriter
{
    private readonly IStorageService _storage;

    public EmbeddedTrackAssetWriter(IStorageService storage)
    {
        _storage = storage;
    }

    public async Task<EmbeddedTrackAssetResult> WriteAsync(
        Guid trackId,
        byte[]? coverData,
        string? coverContentType,
        string? timedLyrics,
        CancellationToken cancellationToken = default)
    {
        if (trackId == Guid.Empty)
            throw new ArgumentException("Track ID is required.", nameof(trackId));

        var cover = ResolveCover(coverData, coverContentType);
        var lyrics = EmbeddedLyricsPolicy.Normalize(timedLyrics);
        var newObjectPaths = new List<string>(capacity: 2);
        string? coverUrl = null;
        string? lyricsUrl = null;

        try
        {
            if (cover != null)
            {
                cancellationToken.ThrowIfCancellationRequested();
                await using var coverStream = new MemoryStream(coverData!, writable: false);
                coverUrl = await _storage.UploadFileAsync(
                    coverStream,
                    $"cover{cover.Value.Extension}",
                    cover.Value.ContentType,
                    $"covers/{trackId}");
                newObjectPaths.Add(coverUrl);
            }

            if (lyrics != null)
            {
                cancellationToken.ThrowIfCancellationRequested();
                await using var lyricsStream = new MemoryStream(
                    Encoding.UTF8.GetBytes(lyrics),
                    writable: false);
                lyricsUrl = await _storage.UploadFileAsync(
                    lyricsStream,
                    "lyrics.lrc",
                    "text/plain; charset=utf-8",
                    $"lyrics/{trackId}");
                newObjectPaths.Add(lyricsUrl);
            }

            return new EmbeddedTrackAssetResult(
                coverUrl,
                lyricsUrl,
                newObjectPaths.AsReadOnly());
        }
        catch
        {
            foreach (var objectPath in newObjectPaths.AsEnumerable().Reverse())
            {
                try
                {
                    await _storage.DeleteFileAsync(objectPath);
                }
                catch
                {
                    // Preserve the original write failure.
                }
            }
            throw;
        }
    }

    public static bool IsSupportedCover(
        byte[]? coverData,
        string? coverContentType)
    {
        if (coverData is not { Length: > 0 }) return false;
        return coverContentType?.Trim().ToLowerInvariant() is
            "image/jpeg" or "image/jpg" or "image/png" or "image/webp";
    }

    private static (string Extension, string ContentType)? ResolveCover(
        byte[]? coverData,
        string? coverContentType)
    {
        if (coverData is not { Length: > 0 }) return null;

        return coverContentType?.Trim().ToLowerInvariant() switch
        {
            "image/jpeg" or "image/jpg" => (".jpg", "image/jpeg"),
            "image/png" => (".png", "image/png"),
            "image/webp" => (".webp", "image/webp"),
            _ => throw new ArgumentException(
                "Embedded cover content type is not supported.",
                nameof(coverContentType))
        };
    }
}
