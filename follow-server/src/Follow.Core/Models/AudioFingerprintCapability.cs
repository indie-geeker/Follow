namespace Follow.Core.Models;

public sealed record AudioFingerprintCapability(
    bool IsAvailable,
    string? Version,
    int Algorithm,
    string? ErrorCode,
    string? ErrorMessage);

public sealed class AudioFingerprintExtractionException : Exception
{
    public AudioFingerprintExtractionException(
        string errorCode,
        string message,
        Exception? innerException = null)
        : base(message, innerException)
    {
        ErrorCode = errorCode;
    }

    public string ErrorCode { get; }
}
