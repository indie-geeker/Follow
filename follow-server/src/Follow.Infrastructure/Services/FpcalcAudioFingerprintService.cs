using System.ComponentModel;
using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Options;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Follow.Infrastructure.Services;

public sealed partial class FpcalcAudioFingerprintService : IAudioFingerprintService
{
    private readonly AudioFingerprintOptions _options;
    private readonly ILogger<FpcalcAudioFingerprintService> _logger;

    public FpcalcAudioFingerprintService(
        IOptions<AudioFingerprintOptions> options,
        ILogger<FpcalcAudioFingerprintService> logger)
    {
        _options = options.Value;
        _logger = logger;
        ValidateOptions(_options);
    }

    public async Task<AudioFingerprintCapability> CheckCapabilityAsync(
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await RunAsync(["-version"], null, cancellationToken);
            if (result.ExitCode != 0)
            {
                return Unavailable(
                    "FINGERPRINT_EXECUTABLE_FAILED",
                    "Fingerprint executable version check failed.");
            }

            var versionText = string.IsNullOrWhiteSpace(result.StandardOutput)
                ? result.StandardError
                : result.StandardOutput;
            var match = VersionRegex().Match(versionText);
            if (!match.Success)
            {
                return Unavailable(
                    "FINGERPRINT_VERSION_UNKNOWN",
                    "Fingerprint executable did not report a recognizable version.");
            }

            var version = match.Groups["version"].Value;
            if (!version.StartsWith(_options.RequiredVersionPrefix, StringComparison.Ordinal))
            {
                return new AudioFingerprintCapability(
                    false,
                    version,
                    _options.Algorithm,
                    "FINGERPRINT_VERSION_INCOMPATIBLE",
                    "Fingerprint executable version is incompatible.");
            }

            return new AudioFingerprintCapability(
                true,
                version,
                _options.Algorithm,
                null,
                null);
        }
        catch (ProcessTimeoutException)
        {
            return Unavailable(
                "FINGERPRINT_TIMEOUT",
                "Fingerprint executable version check timed out.");
        }
        catch (Exception exception) when (
            exception is Win32Exception or FileNotFoundException or DirectoryNotFoundException)
        {
            _logger.LogDebug("Fingerprint executable is unavailable: {ExceptionType}", exception.GetType().Name);
            return Unavailable(
                "FINGERPRINT_EXECUTABLE_UNAVAILABLE",
                "Fingerprint executable is unavailable.");
        }
    }

    public async Task<AudioFingerprint> ExtractAsync(
        Stream source,
        TimeSpan sourceDuration,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(source);
        if (!source.CanRead)
            throw new ArgumentException("Fingerprint source must be readable.", nameof(source));
        if (sourceDuration <= TimeSpan.Zero)
            throw new ArgumentOutOfRangeException(nameof(sourceDuration));

        var capability = await CheckCapabilityAsync(cancellationToken);
        if (!capability.IsAvailable)
        {
            throw new AudioFingerprintExtractionException(
                capability.ErrorCode ?? "FINGERPRINT_UNAVAILABLE",
                capability.ErrorMessage ?? "Fingerprint capability is unavailable.");
        }

        var temporaryPath = await SpoolSourceAsync(source, cancellationToken);
        try
        {
            var result = await RunAsync([
                "-raw",
                "-signed",
                "-json",
                "-algorithm", _options.Algorithm.ToString(),
                "-length", _options.MaximumLengthSeconds.ToString(),
                temporaryPath
            ], null, cancellationToken);

            if (result.StandardOutputExceeded)
            {
                throw new AudioFingerprintExtractionException(
                    "FINGERPRINT_OUTPUT_TOO_LARGE",
                    "Fingerprint output exceeded the configured limit.");
            }

            if (result.ExitCode != 0)
            {
                var boundedError = result.StandardErrorExceeded
                    ? "Fingerprint process error output exceeded the configured limit."
                    : $"Fingerprint process failed with exit code {result.ExitCode}: {result.StandardError}";
                throw new AudioFingerprintExtractionException(
                    "FINGERPRINT_PROCESS_FAILED",
                    boundedError);
            }

            try
            {
                using var document = JsonDocument.Parse(result.StandardOutput);
                var root = document.RootElement;
                var fingerprintElement = root.GetProperty("fingerprint");
                if (fingerprintElement.ValueKind != JsonValueKind.Array)
                    throw new JsonException("Fingerprint must be an array.");

                var frames = fingerprintElement
                    .EnumerateArray()
                    .Select(frame => unchecked((uint)frame.GetInt32()))
                    .ToArray();
                if (frames.Length == 0)
                    throw new JsonException("Fingerprint output is empty.");

                return new AudioFingerprint(
                    _options.Algorithm,
                    capability.Version!,
                    sourceDuration,
                    frames);
            }
            catch (Exception exception) when (
                exception is JsonException or KeyNotFoundException or InvalidOperationException or FormatException)
            {
                throw new AudioFingerprintExtractionException(
                    "FINGERPRINT_OUTPUT_INVALID",
                    "Fingerprint output is not valid raw JSON.",
                    exception);
            }
        }
        catch (ProcessTimeoutException exception)
        {
            throw new AudioFingerprintExtractionException(
                "FINGERPRINT_TIMEOUT",
                "Fingerprint extraction timed out.",
                exception);
        }
        finally
        {
            TryDeleteTemporaryFile(temporaryPath);
        }
    }

    private async Task<string> SpoolSourceAsync(
        Stream source,
        CancellationToken cancellationToken)
    {
        var temporaryDirectory = string.IsNullOrWhiteSpace(_options.TemporaryDirectory)
            ? Path.Combine(Path.GetTempPath(), "follow-fingerprint")
            : Path.GetFullPath(_options.TemporaryDirectory);
        Directory.CreateDirectory(temporaryDirectory);
        var temporaryPath = Path.Combine(temporaryDirectory, $"{Guid.NewGuid():N}.audio");

        try
        {
            await using var destination = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                81920,
                FileOptions.Asynchronous | FileOptions.SequentialScan);
            if (!OperatingSystem.IsWindows())
            {
                File.SetUnixFileMode(
                    temporaryPath,
                    UnixFileMode.UserRead | UnixFileMode.UserWrite);
            }

            var buffer = new byte[81920];
            long totalBytes = 0;
            while (true)
            {
                var read = await source.ReadAsync(buffer, cancellationToken);
                if (read == 0)
                    break;
                totalBytes += read;
                if (totalBytes > _options.MaximumSourceBytes)
                {
                    throw new AudioFingerprintExtractionException(
                        "FINGERPRINT_SOURCE_TOO_LARGE",
                        "Fingerprint source exceeded the configured limit.");
                }
                await destination.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            }
            await destination.FlushAsync(cancellationToken);
            return temporaryPath;
        }
        catch
        {
            if (File.Exists(temporaryPath))
                File.Delete(temporaryPath);
            throw;
        }
    }

    private void TryDeleteTemporaryFile(string temporaryPath)
    {
        try
        {
            if (File.Exists(temporaryPath))
                File.Delete(temporaryPath);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            _logger.LogWarning(
                "Fingerprint temporary-file cleanup failed: {ExceptionType}",
                exception.GetType().Name);
        }
    }

    private async Task<ProcessResult> RunAsync(
        IReadOnlyCollection<string> arguments,
        Stream? standardInput,
        CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = _options.ExecutablePath,
            UseShellExecute = false,
            RedirectStandardInput = standardInput != null,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        foreach (var argument in arguments)
            startInfo.ArgumentList.Add(argument);

        using var process = Process.Start(startInfo)
            ?? throw new Win32Exception("Unable to start fingerprint executable.");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(_options.EffectiveTimeout);

        var stdoutTask = ReadBoundedAsync(
            process.StandardOutput.BaseStream,
            _options.MaximumStandardOutputBytes,
            timeout.Token);
        var stderrTask = ReadBoundedAsync(
            process.StandardError.BaseStream,
            _options.MaximumStandardErrorBytes,
            timeout.Token);
        var stdinTask = standardInput == null
            ? Task.CompletedTask
            : CopyInputAsync(standardInput, process.StandardInput.BaseStream, timeout.Token);

        try
        {
            await Task.WhenAll(
                process.WaitForExitAsync(timeout.Token),
                stdoutTask,
                stderrTask,
                stdinTask);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            TryKill(process);
            throw new ProcessTimeoutException();
        }
        catch
        {
            TryKill(process);
            throw;
        }

        var stdout = await stdoutTask;
        var stderr = await stderrTask;
        return new ProcessResult(
            process.ExitCode,
            stdout.Text,
            stderr.Text,
            stdout.Exceeded,
            stderr.Exceeded);
    }

    private static async Task CopyInputAsync(
        Stream source,
        Stream destination,
        CancellationToken cancellationToken)
    {
        try
        {
            await source.CopyToAsync(destination, cancellationToken);
        }
        finally
        {
            await destination.DisposeAsync();
        }
    }

    private static async Task<BoundedText> ReadBoundedAsync(
        Stream stream,
        int maximumBytes,
        CancellationToken cancellationToken)
    {
        var retained = new MemoryStream(Math.Min(maximumBytes, 64 * 1024));
        var buffer = new byte[4096];
        var exceeded = false;
        while (true)
        {
            var read = await stream.ReadAsync(buffer, cancellationToken);
            if (read == 0)
                break;

            var remaining = maximumBytes - (int)retained.Length;
            if (remaining > 0)
                retained.Write(buffer, 0, Math.Min(remaining, read));
            if (read > remaining)
                exceeded = true;
        }

        return new BoundedText(Encoding.UTF8.GetString(retained.ToArray()), exceeded);
    }

    private static void TryKill(Process process)
    {
        try
        {
            if (!process.HasExited)
                process.Kill(entireProcessTree: true);
        }
        catch (InvalidOperationException)
        {
            // Process already exited between the check and kill request.
        }
    }

    private AudioFingerprintCapability Unavailable(string errorCode, string message) =>
        new(false, null, _options.Algorithm, errorCode, message);

    private static void ValidateOptions(AudioFingerprintOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.ExecutablePath))
            throw new InvalidOperationException("AudioFingerprint:ExecutablePath is required.");
        if (options.Algorithm <= 0)
            throw new InvalidOperationException("AudioFingerprint:Algorithm must be positive.");
        if (options.MaximumLengthSeconds <= 0)
            throw new InvalidOperationException("AudioFingerprint:MaximumLengthSeconds must be positive.");
        if (options.EffectiveTimeout <= TimeSpan.Zero)
            throw new InvalidOperationException("AudioFingerprint timeout must be positive.");
        if (options.MaximumStandardOutputBytes <= 0 || options.MaximumStandardErrorBytes <= 0)
            throw new InvalidOperationException("AudioFingerprint output limits must be positive.");
        if (options.MaximumSourceBytes <= 0)
            throw new InvalidOperationException("AudioFingerprint:MaximumSourceBytes must be positive.");
        if (!string.IsNullOrWhiteSpace(options.TemporaryDirectory) &&
            !Path.IsPathFullyQualified(options.TemporaryDirectory))
        {
            throw new InvalidOperationException(
                "AudioFingerprint:TemporaryDirectory must be an absolute path when configured.");
        }
        if (string.IsNullOrWhiteSpace(options.RequiredVersionPrefix))
            throw new InvalidOperationException("AudioFingerprint:RequiredVersionPrefix is required.");
        if (options.CandidateSimilarityThreshold is < 0 or > 1 ||
            options.MatchSimilarityThreshold is < 0 or > 1 ||
            options.MinimumSegmentSimilarity is < 0 or > 1 ||
            options.MinimumCoverageFraction is <= 0 or > 1 ||
            options.MatchSimilarityThreshold < options.CandidateSimilarityThreshold)
        {
            throw new InvalidOperationException(
                "AudioFingerprint structural similarity thresholds are invalid.");
        }
        if (options.MaximumDurationDifferenceSeconds < 0 ||
            options.MaximumAlignmentOffsetFrames < 0 ||
            options.MaximumCandidateAlignmentOffsetFrames < options.MaximumAlignmentOffsetFrames ||
            options.SegmentCount < 2)
        {
            throw new InvalidOperationException(
                "AudioFingerprint structural bounds are invalid.");
        }
    }

    [GeneratedRegex(@"(?i)(?:fpcalc|chromaprint)\s+(?:version\s+)?(?<version>\d+\.\d+(?:\.\d+)?)")]
    private static partial Regex VersionRegex();

    private sealed record BoundedText(string Text, bool Exceeded);

    private sealed record ProcessResult(
        int ExitCode,
        string StandardOutput,
        string StandardError,
        bool StandardOutputExceeded,
        bool StandardErrorExceeded);

    private sealed class ProcessTimeoutException : Exception;
}
