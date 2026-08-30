namespace Follow.Shared.DTOs;

public sealed record CreateMusicImportRequest(
    string ClientRequestId,
    string RelativeDirectory,
    bool AutoStart = false);

public sealed record MusicImportProgressDto(
    int Pending,
    int Processing,
    int Imported,
    int Duplicate,
    int Skipped,
    int Failed,
    int RetryableFailed,
    int Cancelled,
    long ProcessedBytes);

public sealed record MusicImportBatchDto(
    Guid Id,
    Guid RequestedByUserId,
    string ClientRequestId,
    string RelativeDirectory,
    bool AutoStart,
    string Status,
    int DiscoveredFileCount,
    int IgnoredFileCount,
    long TotalBytes,
    MusicImportProgressDto Progress,
    string? LastErrorCode,
    string? LastError,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    DateTime? ScanStartedAt,
    DateTime? ScanCompletedAt,
    DateTime? StartedAt,
    DateTime? CompletedAt);

public sealed record MusicImportBatchPageDto(
    IReadOnlyList<MusicImportBatchDto> Batches,
    int TotalCount,
    int Page,
    int PageSize,
    int TotalPages);

public sealed record MusicImportItemDto(
    Guid Id,
    string RelativePath,
    string OriginalFileName,
    long SizeBytes,
    DateTime SourceModifiedAt,
    string Status,
    string Stage,
    int AttemptCount,
    bool Retryable,
    Guid? TrackId,
    string? ErrorCode,
    string? ErrorMessage,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    DateTime? StartedAt,
    DateTime? CompletedAt);

public sealed record MusicImportItemPageDto(
    IReadOnlyList<MusicImportItemDto> Items,
    int TotalCount,
    int Page,
    int PageSize,
    int TotalPages);

public sealed record MusicImportCapabilitiesDto(
    bool Enabled,
    bool SourceAvailable,
    string SourceAlias,
    int ProcessingConcurrency);
