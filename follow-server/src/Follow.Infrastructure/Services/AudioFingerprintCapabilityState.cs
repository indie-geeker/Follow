using Follow.Core.Models;

namespace Follow.Infrastructure.Services;

public sealed class AudioFingerprintCapabilityState
{
    private readonly object _gate = new();
    private AudioFingerprintCapability _current = new(
        false,
        null,
        2,
        "FINGERPRINT_NOT_CHECKED",
        "Fingerprint runtime capability has not been checked.");

    public AudioFingerprintCapability Current
    {
        get
        {
            lock (_gate)
                return _current;
        }
    }

    public void Update(AudioFingerprintCapability capability)
    {
        ArgumentNullException.ThrowIfNull(capability);
        lock (_gate)
            _current = capability;
    }

    public bool CanIngest(bool importEnabled) => importEnabled && Current.IsAvailable;
}
