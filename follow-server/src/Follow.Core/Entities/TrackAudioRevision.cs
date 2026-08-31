namespace Follow.Core.Entities;

public enum TrackAudioRevisionCleanupStatus
{
    NotRequired,
    Pending,
    Completed,
    Failed
}

/// <summary>
/// Immutable audit facts for an administrator-confirmed replacement of Track audio.
/// </summary>
public class TrackAudioRevision : BaseEntity
{
    public Guid TrackId { get; set; }
    public Guid ReviewGroupId { get; set; }
    public Guid ActingUserId { get; set; }
    public required string PreviousObjectPath { get; set; }
    public required string ReplacementObjectPath { get; set; }
    public byte[]? PreviousContentSha256 { get; set; }
    public byte[]? ReplacementContentSha256 { get; set; }
    public string? PreviousCodec { get; set; }
    public string? ReplacementCodec { get; set; }
    public string? PreviousContainer { get; set; }
    public string? ReplacementContainer { get; set; }
    public bool? PreviousIsLossless { get; set; }
    public bool? ReplacementIsLossless { get; set; }
    public int? PreviousSampleRateHz { get; set; }
    public int? ReplacementSampleRateHz { get; set; }
    public int? PreviousBitDepth { get; set; }
    public int? ReplacementBitDepth { get; set; }
    public int? PreviousChannels { get; set; }
    public int? ReplacementChannels { get; set; }
    public int? PreviousBitRateKbps { get; set; }
    public int? ReplacementBitRateKbps { get; set; }
    public long? PreviousFileSizeBytes { get; set; }
    public long? ReplacementFileSizeBytes { get; set; }
    public long? PreviousExactDurationMilliseconds { get; set; }
    public long? ReplacementExactDurationMilliseconds { get; set; }
    public string? PreviousFingerprintVersion { get; set; }
    public string? ReplacementFingerprintVersion { get; set; }
    public int? PreviousFingerprintAlgorithm { get; set; }
    public int? ReplacementFingerprintAlgorithm { get; set; }
    public byte[]? PreviousFingerprintPayload { get; set; }
    public byte[]? ReplacementFingerprintPayload { get; set; }
    public int? PreviousFingerprintFrameCount { get; set; }
    public int? ReplacementFingerprintFrameCount { get; set; }
    public long? PreviousFingerprintDurationMilliseconds { get; set; }
    public long? ReplacementFingerprintDurationMilliseconds { get; set; }
    public Guid? StorageDeletionJobId { get; set; }
    public TrackAudioRevisionCleanupStatus CleanupStatus { get; set; }
    public int Version { get; set; }

    public Track Track { get; set; } = null!;
    public MusicImportReviewGroup ReviewGroup { get; set; } = null!;
    public User ActingUser { get; set; } = null!;
    public StorageDeletionJob? StorageDeletionJob { get; set; }
}
