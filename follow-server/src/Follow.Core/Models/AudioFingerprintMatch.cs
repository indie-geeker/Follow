namespace Follow.Core.Models;

public enum AudioFingerprintMatchDisposition
{
    Match,
    Different,
    Uncertain,
    Incompatible,
    Invalid
}

public sealed record AudioFingerprintMatch(
    double Similarity,
    int OverlapFrames,
    int OffsetFrames,
    AudioFingerprintMatchDisposition Disposition,
    string Reason);
