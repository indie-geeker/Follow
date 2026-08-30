namespace Follow.Core.Entities;

/// <summary>
/// Durable state for one administrator-requested library scan/import.
/// </summary>
public class MusicImportBatch : BaseEntity
{
    public Guid RequestedByUserId { get; set; }
    public required string ClientRequestId { get; set; }
    public string RelativeDirectory { get; set; } = string.Empty;
    public bool AutoStart { get; set; }
    public MusicImportBatchStatus Status { get; set; } = MusicImportBatchStatus.Pending;
    public int DiscoveredFileCount { get; set; }
    public int IgnoredFileCount { get; set; }
    public long TotalBytes { get; set; }
    public DateTime? ScanStartedAt { get; set; }
    public DateTime? ScanCompletedAt { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public DateTime? CancelRequestedAt { get; set; }
    public string? LeaseOwner { get; set; }
    public DateTime? LeaseExpiresAt { get; set; }
    public string? LastErrorCode { get; set; }
    public string? LastError { get; set; }
    public int Version { get; set; }

    public User? RequestedByUser { get; set; }
    public ICollection<MusicImportItem> Items { get; set; } = [];
}
