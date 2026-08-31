using System.Diagnostics;

namespace Follow.Api.Tests;

internal sealed class GeneratedAudioFixture : IAsyncDisposable
{
    private GeneratedAudioFixture(
        string directoryPath,
        IReadOnlyList<string> positiveVariants,
        IReadOnlyList<string> negativeVariants)
    {
        DirectoryPath = directoryPath;
        PositiveVariants = positiveVariants;
        NegativeVariants = negativeVariants;
    }

    public string DirectoryPath { get; }
    public string ReferenceFile => PositiveVariants[0];
    public IReadOnlyList<string> PositiveVariants { get; }
    public IReadOnlyList<string> NegativeVariants { get; }

    public static async Task<GeneratedAudioFixture> CreateAsync(
        CancellationToken cancellationToken = default)
    {
        var directoryPath = Path.Combine(
            Path.GetTempPath(),
            $"follow-audio-calibration-{Guid.NewGuid():N}");
        Directory.CreateDirectory(directoryPath);

        try
        {
            var reference = Path.Combine(directoryPath, "reference.wav");
            var flac = Path.Combine(directoryPath, "reference.flac");
            var mp3 = Path.Combine(directoryPath, "reference.mp3");
            var aac = Path.Combine(directoryPath, "reference.m4a");
            var ogg = Path.Combine(directoryPath, "reference.ogg");
            var tagged = Path.Combine(directoryPath, "tagged.flac");
            var gain = Path.Combine(directoryPath, "gain.flac");
            var different = Path.Combine(directoryPath, "different.wav");
            var introOutro = Path.Combine(directoryPath, "intro-outro.wav");
            var clipped = Path.Combine(directoryPath, "clipped.wav");
            var liveLike = Path.Combine(directoryPath, "live-like.wav");
            var remixTempo = Path.Combine(directoryPath, "remix-tempo.wav");
            var coverLike = Path.Combine(directoryPath, "cover-like.wav");

            await RunFfmpegAsync([
                "-f", "lavfi",
                "-i", "aevalsrc=0.16*sin(2*PI*220*t)+0.11*sin(2*PI*(330+18*t)*t)+0.07*sin(2*PI*440*t):s=44100:d=18",
                "-c:a", "pcm_s16le",
                reference
            ], cancellationToken);
            await RunFfmpegAsync(["-i", reference, "-c:a", "flac", flac], cancellationToken);
            await RunFfmpegAsync(["-i", reference, "-c:a", "libmp3lame", "-b:a", "192k", mp3], cancellationToken);
            await RunFfmpegAsync(["-i", reference, "-c:a", "aac", "-b:a", "192k", aac], cancellationToken);
            await RunFfmpegAsync(["-i", reference, "-c:a", "libopus", "-b:a", "160k", ogg], cancellationToken);
            await RunFfmpegAsync([
                "-i", reference,
                "-c:a", "flac",
                "-metadata", "title=Same recording with different tags",
                "-metadata", "artist=Generated fixture",
                tagged
            ], cancellationToken);
            await RunFfmpegAsync([
                "-i", reference,
                "-filter:a", "volume=0.8",
                "-c:a", "flac",
                gain
            ], cancellationToken);

            await RunFfmpegAsync([
                "-f", "lavfi",
                "-i", "aevalsrc=0.15*sin(2*PI*710*t)+0.10*sin(2*PI*930*t):s=44100:d=18",
                "-c:a", "pcm_s16le",
                different
            ], cancellationToken);
            await RunFfmpegAsync([
                "-i", reference,
                "-filter:a", "adelay=1500|1500,apad=pad_dur=1.5",
                "-c:a", "pcm_s16le",
                introOutro
            ], cancellationToken);
            await RunFfmpegAsync([
                "-ss", "2",
                "-i", reference,
                "-t", "14",
                "-c:a", "pcm_s16le",
                clipped
            ], cancellationToken);
            await RunFfmpegAsync([
                "-i", reference,
                "-filter:a", "aecho=0.8:0.7:60:0.35",
                "-c:a", "pcm_s16le",
                liveLike
            ], cancellationToken);
            await RunFfmpegAsync([
                "-i", reference,
                "-filter:a", "atempo=1.08",
                "-c:a", "pcm_s16le",
                remixTempo
            ], cancellationToken);
            await RunFfmpegAsync([
                "-f", "lavfi",
                "-i", "aevalsrc=0.16*sin(2*PI*247*t)+0.11*sin(2*PI*(370+18*t)*t)+0.07*sin(2*PI*494*t):s=44100:d=18",
                "-c:a", "pcm_s16le",
                coverLike
            ], cancellationToken);

            return new GeneratedAudioFixture(
                directoryPath,
                [reference, flac, mp3, aac, ogg, tagged, gain],
                [different, introOutro, clipped, liveLike, remixTempo, coverLike]);
        }
        catch
        {
            Directory.Delete(directoryPath, recursive: true);
            throw;
        }
    }

    public ValueTask DisposeAsync()
    {
        if (Directory.Exists(DirectoryPath))
            Directory.Delete(DirectoryPath, recursive: true);
        return ValueTask.CompletedTask;
    }

    private static async Task RunFfmpegAsync(
        IReadOnlyCollection<string> arguments,
        CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "ffmpeg",
            UseShellExecute = false,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        startInfo.ArgumentList.Add("-hide_banner");
        startInfo.ArgumentList.Add("-loglevel");
        startInfo.ArgumentList.Add("error");
        startInfo.ArgumentList.Add("-y");
        foreach (var argument in arguments)
            startInfo.ArgumentList.Add(argument);

        using var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("Unable to start ffmpeg for generated audio fixtures.");
        var stderrTask = process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken);
        var stderr = await stderrTask;
        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException(
                $"ffmpeg fixture generation failed with exit code {process.ExitCode}: {stderr}");
        }
    }
}
