namespace Follow.Core.Entities;

/// <summary>
/// Durable audit and processing state for one source file in an import batch.
/// </summary>
public class MusicImportItem : BaseEntity
{
    public MusicImportSourceKind SourceKind { get; set; } = MusicImportSourceKind.MountedDirectory;
    public string? SourceReference { get; set; }
    public string? StagingObjectPath { get; set; }
    public string? SourceETag { get; set; }
    public Guid BatchId { get; set; }
    public required string RelativePath { get; set; }
    public required string OriginalFileName { get; set; }
    public required string Extension { get; set; }
    public long SizeBytes { get; set; }
    public DateTime SourceModifiedAt { get; set; }
    public string? Codec { get; set; }
    public string? Container { get; set; }
    public bool? IsLossless { get; set; }
    public int? SampleRateHz { get; set; }
    public int? BitDepth { get; set; }
    public int? Channels { get; set; }
    public int? BitRateKbps { get; set; }
    public long? ExactDurationMilliseconds { get; set; }
    public string? ExtractedTitle { get; set; }
    public string? ExtractedArtist { get; set; }
    public string? ExtractedAlbum { get; set; }
    public byte[]? ContentSha256 { get; set; }
    public string? FingerprintVersion { get; set; }
    public int? FingerprintAlgorithm { get; set; }
    public byte[]? FingerprintPayload { get; set; }
    public int? FingerprintFrameCount { get; set; }
    public long? FingerprintDurationMilliseconds { get; set; }
    public MusicImportItemStatus Status { get; set; } = MusicImportItemStatus.Pending;
    public MusicImportItemStage Stage { get; set; } = MusicImportItemStage.None;
    public int AttemptCount { get; set; }
    public bool Retryable { get; set; }
    public DateTime NextAttemptAt { get; set; } = DateTime.UtcNow;
    public string? LeaseOwner { get; set; }
    public DateTime? LeaseExpiresAt { get; set; }
    public string? ObjectPath { get; set; }
    public Guid? TrackId { get; set; }
    public Guid? ReviewGroupId { get; set; }
    public MusicImportDecisionKind? Decision { get; set; }
    public Guid? DecisionTrackId { get; set; }
    public string? ErrorCode { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public int Version { get; set; }

    public MusicImportBatch Batch { get; set; } = null!;
    public Track? Track { get; set; }
    public MusicImportReviewGroup? ReviewGroup { get; set; }
}
