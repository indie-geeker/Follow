using Follow.Core.Models;
using Follow.Infrastructure.Options;
using Follow.Infrastructure.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace Follow.Api.Tests;

public class FpcalcAudioFingerprintServiceTests
{
    [Fact]
    public async Task Extract_UsesRawJsonContractAndConvertsSignedFrames()
    {
        await using var executable = await FakeExecutable.CreateAsync("""
            if [ "$1" = "-version" ]; then
              echo "fpcalc version 1.6.1"
              exit 0
            fi
            if [ "$1" != "-raw" ] || [ "$2" != "-signed" ] || [ "$3" != "-json" ] || [ "$4" != "-algorithm" ] || [ "$5" != "2" ] || [ "$6" != "-length" ] || [ "$7" != "120" ] || [ ! -f "$8" ]; then
              echo "unexpected arguments" >&2
              exit 19
            fi
            printf '{"duration":18.25,"fingerprint":[0,-1,2147483647,-2147483648]}'
            """);
        var service = CreateService(executable.Path);
        await using var input = new MemoryStream([1, 2, 3, 4]);

        var fingerprint = await service.ExtractAsync(input, TimeSpan.FromSeconds(18.25));

        Assert.Equal(2, fingerprint.Algorithm);
        Assert.Equal("1.6.1", fingerprint.Version);
        Assert.Equal(TimeSpan.FromSeconds(18.25), fingerprint.SourceDuration);
        Assert.Equal([0u, uint.MaxValue, 2_147_483_647u, 2_147_483_648u], fingerprint.Frames);
    }

    [Fact]
    public async Task Extract_UsesTrustedMetadataDurationWhenStdinJsonDurationIsZero()
    {
        await using var executable = await FakeExecutable.CreateAsync("""
            if [ "$1" = "-version" ]; then
              echo "fpcalc version 1.6.1"
              exit 0
            fi
            cat >/dev/null
            printf '{"duration":0.00,"fingerprint":[1,2,3]}'
            """);
        var service = CreateService(executable.Path);

        var fingerprint = await service.ExtractAsync(
            new MemoryStream([1, 2, 3]),
            TimeSpan.FromSeconds(18.25));

        Assert.Equal(TimeSpan.FromSeconds(18.25), fingerprint.SourceDuration);
    }

    [Fact]
    public async Task Extract_UsesPrivateSeekableTempFileAndDeletesIt()
    {
        var temporaryDirectory = System.IO.Path.Combine(
            System.IO.Path.GetTempPath(),
            $"follow-fingerprint-spool-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(temporaryDirectory);
        try
        {
            await using var executable = await FakeExecutable.CreateAsync("""
                if [ "$1" = "-version" ]; then
                  echo "fpcalc version 1.6.1"
                  exit 0
                fi
                if [ "$8" = "-" ] || [ ! -f "$8" ]; then
                  echo "seekable private file required" >&2
                  exit 21
                fi
                printf '{"duration":0.00,"fingerprint":[1,2,3]}'
                """);
            var service = CreateService(
                executable.Path,
                temporaryDirectory: temporaryDirectory);

            var fingerprint = await service.ExtractAsync(
                new MemoryStream([1, 2, 3]),
                TimeSpan.FromSeconds(18));

            Assert.Equal([1u, 2u, 3u], fingerprint.Frames);
            Assert.Empty(Directory.EnumerateFiles(temporaryDirectory));
        }
        finally
        {
            Directory.Delete(temporaryDirectory, recursive: true);
        }
    }

    [Fact]
    public async Task Capability_RejectsIncompatibleVersion()
    {
        await using var executable = await FakeExecutable.CreateAsync("""
            echo "fpcalc version 1.5.1"
            """);
        var service = CreateService(executable.Path);

        var capability = await service.CheckCapabilityAsync();

        Assert.False(capability.IsAvailable);
        Assert.Equal("FINGERPRINT_VERSION_INCOMPATIBLE", capability.ErrorCode);
        Assert.Equal("1.5.1", capability.Version);
    }

    [Fact]
    public async Task Capability_ReportsMissingExecutableWithoutThrowing()
    {
        var service = CreateService(Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N")));

        var capability = await service.CheckCapabilityAsync();

        Assert.False(capability.IsAvailable);
        Assert.Equal("FINGERPRINT_EXECUTABLE_UNAVAILABLE", capability.ErrorCode);
    }

    [Fact]
    public async Task Extract_TimesOutAndFailsClosed()
    {
        await using var executable = await FakeExecutable.CreateAsync("""
            if [ "$1" = "-version" ]; then
              echo "fpcalc version 1.6.1"
              exit 0
            fi
            sleep 2
            """);
        var service = CreateService(executable.Path, timeout: TimeSpan.FromMilliseconds(100));

        var error = await Assert.ThrowsAsync<AudioFingerprintExtractionException>(() =>
            service.ExtractAsync(new MemoryStream([1, 2, 3]), TimeSpan.FromSeconds(18)));

        Assert.Equal("FINGERPRINT_TIMEOUT", error.ErrorCode);
    }

    [Fact]
    public async Task Extract_RejectsNonZeroExitAndBoundsStderr()
    {
        await using var executable = await FakeExecutable.CreateAsync("""
            if [ "$1" = "-version" ]; then
              echo "fpcalc version 1.6.1"
              exit 0
            fi
            head -c 2048 /dev/zero | tr '\000' 'x' >&2
            exit 7
            """);
        var service = CreateService(executable.Path, maximumStderrBytes: 64);

        var error = await Assert.ThrowsAsync<AudioFingerprintExtractionException>(() =>
            service.ExtractAsync(new MemoryStream([1, 2, 3]), TimeSpan.FromSeconds(18)));

        Assert.Equal("FINGERPRINT_PROCESS_FAILED", error.ErrorCode);
        Assert.True(error.Message.Length < 512);
    }

    [Fact]
    public async Task Extract_RejectsMalformedJson()
    {
        await using var executable = await FakeExecutable.CreateAsync("""
            if [ "$1" = "-version" ]; then
              echo "fpcalc version 1.6.1"
              exit 0
            fi
            cat >/dev/null
            printf 'not-json'
            """);
        var service = CreateService(executable.Path);

        var error = await Assert.ThrowsAsync<AudioFingerprintExtractionException>(() =>
            service.ExtractAsync(new MemoryStream([1, 2, 3]), TimeSpan.FromSeconds(18)));

        Assert.Equal("FINGERPRINT_OUTPUT_INVALID", error.ErrorCode);
    }

    [Fact]
    public async Task Extract_RejectsOversizedStdout()
    {
        await using var executable = await FakeExecutable.CreateAsync("""
            if [ "$1" = "-version" ]; then
              echo "fpcalc version 1.6.1"
              exit 0
            fi
            head -c 2048 /dev/zero | tr '\000' '1'
            """);
        var service = CreateService(executable.Path, maximumStdoutBytes: 64);

        var error = await Assert.ThrowsAsync<AudioFingerprintExtractionException>(() =>
            service.ExtractAsync(new MemoryStream([1, 2, 3]), TimeSpan.FromSeconds(18)));

        Assert.Equal("FINGERPRINT_OUTPUT_TOO_LARGE", error.ErrorCode);
    }

    [Fact]
    public async Task CapabilityState_DisablesIngestionUntilCompatibleRuntimeIsReady()
    {
        var state = new AudioFingerprintCapabilityState();

        Assert.False(state.CanIngest(importEnabled: true));

        state.Update(new AudioFingerprintCapability(
            true,
            "1.6.1",
            2,
            null,
            null));

        Assert.True(state.CanIngest(importEnabled: true));
        Assert.False(state.CanIngest(importEnabled: false));
    }

    [Fact]
    public void Options_ExposeTheCalibratedStructuralThresholds()
    {
        var options = new AudioFingerprintOptions
        {
            CandidateSimilarityThreshold = 0.85,
            MatchSimilarityThreshold = 0.99,
            MinimumSegmentSimilarity = 0.98,
            MinimumCoverageFraction = 0.85,
            MaximumDurationDifferenceSeconds = 2,
            MaximumAlignmentOffsetFrames = 2,
            MaximumCandidateAlignmentOffsetFrames = 512,
            SegmentCount = 3
        };

        var structural = options.ToStructuralOptions();

        Assert.Equal(0.85, structural.CandidateSimilarityThreshold);
        Assert.Equal(0.99, structural.MatchSimilarityThreshold);
        Assert.Equal(0.98, structural.MinimumSegmentSimilarity);
        Assert.Equal(0.85, structural.MinimumCoverageFraction);
        Assert.Equal(TimeSpan.FromSeconds(2), structural.MaximumDurationDifference);
        Assert.Equal(2, structural.MaximumAlignmentOffsetFrames);
        Assert.Equal(512, structural.MaximumCandidateAlignmentOffsetFrames);
        Assert.Equal(3, structural.SegmentCount);
    }

    [Fact]
    public void Constructor_RejectsUnsafeStructuralThresholdConfiguration()
    {
        var configured = Options.Create(new AudioFingerprintOptions
        {
            ExecutablePath = "fpcalc",
            CandidateSimilarityThreshold = 0.90,
            MatchSimilarityThreshold = 0.80
        });

        Assert.Throws<InvalidOperationException>(() =>
            new FpcalcAudioFingerprintService(
                configured,
                NullLogger<FpcalcAudioFingerprintService>.Instance));
    }

    private static FpcalcAudioFingerprintService CreateService(
        string executablePath,
        TimeSpan? timeout = null,
        int maximumStdoutBytes = 1024 * 1024,
        int maximumStderrBytes = 16 * 1024,
        string? temporaryDirectory = null) =>
        new(
            Options.Create(new AudioFingerprintOptions
            {
                ExecutablePath = executablePath,
                Algorithm = 2,
                MaximumLengthSeconds = 120,
                Timeout = timeout ?? TimeSpan.FromSeconds(2),
                MaximumStandardOutputBytes = maximumStdoutBytes,
                MaximumStandardErrorBytes = maximumStderrBytes,
                TemporaryDirectory = temporaryDirectory ?? string.Empty,
                MaximumSourceBytes = 1024 * 1024,
                RequiredVersionPrefix = "1.6."
            }),
            NullLogger<FpcalcAudioFingerprintService>.Instance);

    private sealed class FakeExecutable : IAsyncDisposable
    {
        private FakeExecutable(string directoryPath, string path)
        {
            DirectoryPath = directoryPath;
            Path = path;
        }

        private string DirectoryPath { get; }
        public string Path { get; }

        public static async Task<FakeExecutable> CreateAsync(string body)
        {
            if (OperatingSystem.IsWindows())
                throw new PlatformNotSupportedException("Shell-backed fpcalc fakes require Unix.");
            var directoryPath = System.IO.Path.Combine(
                System.IO.Path.GetTempPath(),
                $"follow-fpcalc-fake-{Guid.NewGuid():N}");
            Directory.CreateDirectory(directoryPath);
            var path = System.IO.Path.Combine(directoryPath, "fpcalc-fake");
            await File.WriteAllTextAsync(path, $"#!/bin/sh\nset -eu\n{body}\n");
            File.SetUnixFileMode(
                path,
                UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
            return new FakeExecutable(directoryPath, path);
        }

        public ValueTask DisposeAsync()
        {
            if (Directory.Exists(DirectoryPath))
                Directory.Delete(DirectoryPath, recursive: true);
            return ValueTask.CompletedTask;
        }
    }
}
