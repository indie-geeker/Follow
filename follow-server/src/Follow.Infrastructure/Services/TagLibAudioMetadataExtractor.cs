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

        var container = Path.GetExtension(fileName).TrimStart('.').ToLowerInvariant();
        var audioCodecs = tagFile.Properties.Codecs
            .Where(codec => codec != null &&
                (codec.MediaTypes & TagLib.MediaTypes.Audio) != 0)
            .ToArray();
        var codec = NormalizeCodec(
            audioCodecs.FirstOrDefault()?.Description ?? tagFile.Properties.Description,
            container);
        var duration = tagFile.Properties.Duration;
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
            container,
            coverData,
            coverContentType,
            Codec: codec,
            Container: container,
            IsLossless: InferLossless(audioCodecs, codec),
            SampleRateHz: PositiveOrNull(tagFile.Properties.AudioSampleRate),
            BitDepth: PositiveOrNull(tagFile.Properties.BitsPerSample),
            Channels: PositiveOrNull(tagFile.Properties.AudioChannels),
            BitRateKbps: PositiveOrNull(tagFile.Properties.AudioBitrate),
            ExactDurationMilliseconds: checked((long)Math.Round(duration.TotalMilliseconds)),
            TimedLyrics: EmbeddedLyricsPolicy.Normalize(tagFile.Tag.Lyrics));
        return Task.FromResult(metadata);
    }

    private static int? PositiveOrNull(int value) => value > 0 ? value : null;

    private static bool? InferLossless(
        IReadOnlyCollection<TagLib.ICodec> codecs,
        string normalizedCodec)
    {
        if (codecs.Count > 0)
            return codecs.Any(candidate => candidate is TagLib.ILosslessAudioCodec);
        return normalizedCodec switch
        {
            "flac" or "alac" or "pcm" => true,
            "aac" or "mp3" or "opus" or "vorbis" => false,
            _ => null
        };
    }

    private static string NormalizeCodec(string? description, string container)
    {
        var value = description?.Trim().ToLowerInvariant() ?? string.Empty;
        if (value.Contains("flac", StringComparison.Ordinal)) return "flac";
        if (value.Contains("alac", StringComparison.Ordinal)) return "alac";
        if (value.Contains("aac", StringComparison.Ordinal)) return "aac";
        if (value.Contains("mp4a", StringComparison.Ordinal)) return "aac";
        if (value.Contains("mpeg audio layer 3", StringComparison.Ordinal) ||
            value.Contains("mp3", StringComparison.Ordinal)) return "mp3";
        if (value.Contains("opus", StringComparison.Ordinal)) return "opus";
        if (value.Contains("vorbis", StringComparison.Ordinal)) return "vorbis";
        if (value.Contains("wave", StringComparison.Ordinal) ||
            value.Contains("pcm", StringComparison.Ordinal)) return "pcm";
        return container;
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
