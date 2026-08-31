namespace Follow.Core.Models;

public sealed record AudioFingerprint(
    int Algorithm,
    string Version,
    TimeSpan SourceDuration,
    IReadOnlyList<uint> Frames);
