namespace Follow.Shared.DTOs;

public sealed record MusicImportReviewDecisionRequest(
    int ExpectedVersion,
    string DecisionKind,
    IReadOnlyList<Guid> SelectedItemIds);

public sealed record MusicImportReviewVersionRequest(
    Guid GroupId,
    int ExpectedVersion);

public sealed record MusicImportLockRequest(
    IReadOnlyList<MusicImportReviewVersionRequest> Groups);

public sealed record MusicImportReviewBatchDto(
    Guid BatchId,
    string Status,
    int Version,
    MusicImportReviewSummaryDto Summary,
    IReadOnlyList<MusicImportReviewGroupDto> Groups,
    int TotalCount,
    int Page,
    int PageSize,
    int TotalPages);

public sealed record MusicImportReviewSummaryDto(
    int Open,
    int Confirmed,
    int Locked,
    int Applied,
    int Deferred,
    int Conflict,
    int Failed);

public sealed record MusicImportReviewBatchStateDto(
    Guid Id,
    string Status,
    int Version);

public sealed record MusicImportReviewGroupDto(
    Guid Id,
    Guid BatchId,
    string Status,
    string MatchKind,
    string MatchExplanation,
    int Version,
    Guid? ExistingTrackId,
    MusicImportExistingTrackDto? ExistingTrack,
    Guid? RecommendedItemId,
    string? RecommendationExplanation,
    string? FingerprintVersion,
    int? FingerprintAlgorithm,
    double? OverallSimilarity,
    double? MinimumSegmentSimilarity,
    double? CoverageFraction,
    int? AlignmentOffsetFrames,
    Guid? ConfirmedByUserId,
    DateTime? ConfirmedAt,
    string? DecisionKind,
    IReadOnlyList<Guid> SelectedItemIds,
    string? ApplyErrorCode,
    string? ApplyErrorMessage,
    string? CleanupStatus,
    string? CleanupErrorCode,
    string? CleanupErrorMessage,
    IReadOnlyList<MusicImportReviewCandidateDto> Candidates);

public sealed record MusicImportExistingTrackDto(
    Guid Id,
    string Title,
    string? OriginalFileName,
    string? Codec,
    string? Container,
    bool? IsLossless,
    int? SampleRateHz,
    int? BitDepth,
    int? Channels,
    int? BitRateKbps,
    long? FileSizeBytes,
    long? ExactDurationMilliseconds);

public sealed record MusicImportReviewCandidateDto(
    Guid Id,
    int Version,
    string RelativePath,
    string SourceLabel,
    string OriginalFileName,
    string SourceKind,
    string? ExtractedTitle,
    string? ExtractedArtist,
    string? ExtractedAlbum,
    string? Codec,
    string? Container,
    bool? IsLossless,
    int? SampleRateHz,
    int? BitDepth,
    int? Channels,
    int? BitRateKbps,
    long SizeBytes,
    long? ExactDurationMilliseconds,
    string? Decision,
    Guid? DecisionTrackId,
    bool PreviewAvailable,
    string? PreviewUrl);
