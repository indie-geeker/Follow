namespace Follow.Core.Models;

public sealed record AudioQualityFacts(
    string? Codec,
    string? Container,
    bool? IsLossless,
    int? SampleRateHz,
    int? BitDepth,
    int? Channels,
    int? BitRateKbps,
    long? FileSizeBytes);
