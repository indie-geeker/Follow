using Follow.Core.Interfaces;
using Follow.Core.Services;

namespace Follow.Infrastructure.Services;

public sealed class TagLibAudioMetadataExtractor : IAudioMetadataExtractor
{
    public Task<AudioMetadata> ExtractAsync(
        Stream source,
        string fileName,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(source);
        if (!source.CanRead || !source.CanSeek)
            throw new ArgumentException("Metadata source must be readable and seekable.", nameof(source));
        cancellationToken.ThrowIfCancellationRequested();
        source.Position = 0;
        using var tagFile = TagLib.File.Create(new StreamFileAbstraction(source, fileName));
        cancellationToken.ThrowIfCancellationRequested();

        var picture = tagFile.Tag.Pictures.FirstOrDefault(candidate =>
            candidate.Data.Count > 0 &&
            NormalizeCoverContentType(candidate.MimeType) != null);
        var coverContentType = picture == null
            ? null
            : NormalizeCoverContentType(picture.MimeType);
        var coverData = picture?.Data.Data.ToArray();

        var metadata = new AudioMetadata(
            string.IsNullOrWhiteSpace(tagFile.Tag.Title)
                ? Path.GetFileNameWithoutExtension(fileName)
                : tagFile.Tag.Title.Trim(),
            tagFile.Tag.Performers.FirstOrDefault()?.Trim(),
            string.IsNullOrWhiteSpace(tagFile.Tag.Album)
                ? null
                : tagFile.Tag.Album.Trim(),
            (int)Math.Ceiling(tagFile.Properties.Duration.TotalSeconds),
            tagFile.Properties.AudioBitrate,
            Path.GetExtension(fileName).TrimStart('.').ToLowerInvariant(),
            coverData,
            coverContentType,
            EmbeddedLyricsPolicy.Normalize(tagFile.Tag.Lyrics));
        return Task.FromResult(metadata);
    }

    private static string? NormalizeCoverContentType(string? contentType) =>
        contentType?.Trim().ToLowerInvariant() switch
        {
            "image/jpeg" or "image/jpg" => "image/jpeg",
            "image/png" => "image/png",
            "image/webp" => "image/webp",
            _ => null
        };

    private sealed class StreamFileAbstraction : TagLib.File.IFileAbstraction
    {
        private readonly Stream _source;

        public StreamFileAbstraction(Stream source, string fileName)
        {
            _source = source;
            Name = fileName;
        }

        public string Name { get; }
        public Stream ReadStream => _source;
        public Stream WriteStream => _source;

        public void CloseStream(Stream stream)
        {
            // The processor owns the single read handle across hash, metadata, and upload.
        }
    }
}
