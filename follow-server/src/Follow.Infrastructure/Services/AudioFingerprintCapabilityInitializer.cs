using Follow.Core.Interfaces;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Follow.Infrastructure.Services;

public sealed class AudioFingerprintCapabilityInitializer : IHostedService
{
    private readonly IAudioFingerprintService _fingerprintService;
    private readonly AudioFingerprintCapabilityState _state;
    private readonly ILogger<AudioFingerprintCapabilityInitializer> _logger;

    public AudioFingerprintCapabilityInitializer(
        IAudioFingerprintService fingerprintService,
        AudioFingerprintCapabilityState state,
        ILogger<AudioFingerprintCapabilityInitializer> logger)
    {
        _fingerprintService = fingerprintService;
        _state = state;
        _logger = logger;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        var capability = await _fingerprintService.CheckCapabilityAsync(cancellationToken);
        _state.Update(capability);
        if (!capability.IsAvailable)
        {
            _logger.LogWarning(
                "Music ingestion disabled because acoustic fingerprint capability failed: {ErrorCode}",
                capability.ErrorCode);
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
