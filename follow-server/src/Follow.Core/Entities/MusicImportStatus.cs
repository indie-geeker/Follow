namespace Follow.Core.Entities;

public enum MusicImportBatchStatus
{
    Pending,
    Scanning,
    Ready,
    Analyzing,
    Grouping,
    AwaitingReview,
    ReadyToApply,
    Applying,
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
    SourceValidation,
    Hashing,
    Metadata,
    Fingerprinting,
    Analyzed,
    Grouped,
    AwaitingReview,
    Applying,
    Verified,
    // Legacy stages retained until the old pre-review processor is removed.
    Parsing,
    Uploading,
    Persisting
}
