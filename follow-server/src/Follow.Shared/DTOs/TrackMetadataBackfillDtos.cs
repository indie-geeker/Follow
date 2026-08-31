namespace Follow.Shared.DTOs;

public sealed record TrackMetadataBackfillRequest(
    bool DryRun,
    Guid? AfterId = null,
    int Limit = 50);

public sealed record TrackMetadataBackfillEntryDto(
    Guid TrackId,
    string Status,
    bool CoverAvailable,
    bool LyricsAvailable,
    bool CoverUpdated,
    bool LyricsUpdated,
    string? ErrorCode);

public sealed record TrackMetadataBackfillResponse(
    bool DryRun,
    int CandidateCount,
    int SupportedCoverCount,
    int SupportedLyricsCount,
    int UpdatedCount,
    int FailedCount,
    Guid? NextAfterId,
    IReadOnlyList<TrackMetadataBackfillEntryDto> Entries);
