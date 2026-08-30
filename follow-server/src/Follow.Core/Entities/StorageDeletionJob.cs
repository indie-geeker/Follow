namespace Follow.Core.Entities;

public class StorageDeletionJob : BaseEntity
{
    public required string ObjectPath { get; set; }
    public int AttemptCount { get; set; }
    public DateTime NextAttemptAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }
    public string? LastError { get; set; }
}
