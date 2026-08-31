namespace Follow.Core.Entities;

/// <summary>
/// Durable manual-review boundary for candidates that may represent one recording.
/// A recommendation is presentation data and never confirms the group.
/// </summary>
public class MusicImportReviewGroup : BaseEntity
{
    public Guid BatchId { get; set; }
    public MusicImportReviewStatus Status { get; set; } = MusicImportReviewStatus.Open;
    public MusicImportMatchKind MatchKind { get; set; } = MusicImportMatchKind.None;
    public Guid? ExistingTrackId { get; set; }
    public Guid? RecommendedItemId { get; set; }
    public string? RecommendationExplanation { get; set; }
    public string? FingerprintVersion { get; set; }
    public int? FingerprintAlgorithm { get; set; }
    public double? OverallSimilarity { get; set; }
    public double? MinimumSegmentSimilarity { get; set; }
    public double? CoverageFraction { get; set; }
    public int? AlignmentOffsetFrames { get; set; }
    public Guid? ConfirmedByUserId { get; set; }
    public DateTime? ConfirmedAt { get; set; }
    public string? ApplyErrorCode { get; set; }
    public string? ApplyErrorMessage { get; set; }
    public int Version { get; set; }

    public MusicImportBatch Batch { get; set; } = null!;
    public Track? ExistingTrack { get; set; }
    public MusicImportItem? RecommendedItem { get; set; }
    public User? ConfirmedByUser { get; set; }
    public ICollection<MusicImportItem> Items { get; set; } = [];
    public ICollection<TrackAudioRevision> AudioRevisions { get; set; } = [];
}
