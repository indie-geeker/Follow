using Follow.Core.Models;

namespace Follow.Core.Interfaces;

public interface IAudioFingerprintService
{
    Task<AudioFingerprintCapability> CheckCapabilityAsync(
        CancellationToken cancellationToken = default);

    Task<AudioFingerprint> ExtractAsync(
        Stream source,
        TimeSpan sourceDuration,
        CancellationToken cancellationToken = default);
}
