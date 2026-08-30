namespace Follow.Core.Entities;

public enum MusicImportBatchStatus
{
    Pending,
    Scanning,
    Ready,
    Running,
    PauseRequested,
    Paused,
    CancelRequested,
    Cancelled,
    Verifying,
    Completed,
    CompletedWithErrors,
    Failed
}

public enum MusicImportItemStatus
{
    Pending,
    Processing,
    Imported,
    Duplicate,
    Skipped,
    Failed,
    Cancelled
}

public enum MusicImportItemStage
{
    None,
    Hashing,
    Parsing,
    Uploading,
    Persisting
}
