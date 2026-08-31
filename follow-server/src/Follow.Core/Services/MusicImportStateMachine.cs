using Follow.Core.Entities;

namespace Follow.Core.Services;

public static class MusicImportStateMachine
{
    public static bool CanTransition(
        MusicImportBatchStatus current,
        MusicImportBatchStatus next) =>
        (current, next) switch
        {
            (MusicImportBatchStatus.Pending, MusicImportBatchStatus.Scanning) => true,
            (MusicImportBatchStatus.Pending, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.Scanning, MusicImportBatchStatus.Ready) => true,
            (MusicImportBatchStatus.Scanning, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.Scanning, MusicImportBatchStatus.Failed) => true,
            (MusicImportBatchStatus.Ready, MusicImportBatchStatus.Analyzing) => true,
            (MusicImportBatchStatus.Ready, MusicImportBatchStatus.Running) => true,
            (MusicImportBatchStatus.Ready, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.Analyzing, MusicImportBatchStatus.Grouping) => true,
            (MusicImportBatchStatus.Analyzing, MusicImportBatchStatus.PauseRequested) => true,
            (MusicImportBatchStatus.Analyzing, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.Analyzing, MusicImportBatchStatus.Failed) => true,
            (MusicImportBatchStatus.Grouping, MusicImportBatchStatus.AwaitingReview) => true,
            (MusicImportBatchStatus.Grouping, MusicImportBatchStatus.PauseRequested) => true,
            (MusicImportBatchStatus.Grouping, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.Grouping, MusicImportBatchStatus.Failed) => true,
            (MusicImportBatchStatus.AwaitingReview, MusicImportBatchStatus.ReadyToApply) => true,
            (MusicImportBatchStatus.AwaitingReview, MusicImportBatchStatus.PauseRequested) => true,
            (MusicImportBatchStatus.AwaitingReview, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.AwaitingReview, MusicImportBatchStatus.Failed) => true,
            (MusicImportBatchStatus.ReadyToApply, MusicImportBatchStatus.Applying) => true,
            (MusicImportBatchStatus.ReadyToApply, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.Applying, MusicImportBatchStatus.Verifying) => true,
            (MusicImportBatchStatus.Applying, MusicImportBatchStatus.AwaitingReview) => true,
            (MusicImportBatchStatus.Applying, MusicImportBatchStatus.PauseRequested) => true,
            (MusicImportBatchStatus.Applying, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.Applying, MusicImportBatchStatus.Failed) => true,
            (MusicImportBatchStatus.Running, MusicImportBatchStatus.PauseRequested) => true,
            (MusicImportBatchStatus.Running, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.Running, MusicImportBatchStatus.Verifying) => true,
            (MusicImportBatchStatus.Running, MusicImportBatchStatus.Failed) => true,
            (MusicImportBatchStatus.PauseRequested, MusicImportBatchStatus.Paused) => true,
            (MusicImportBatchStatus.PauseRequested, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.Paused, MusicImportBatchStatus.Analyzing) => true,
            (MusicImportBatchStatus.Paused, MusicImportBatchStatus.Grouping) => true,
            (MusicImportBatchStatus.Paused, MusicImportBatchStatus.AwaitingReview) => true,
            (MusicImportBatchStatus.Paused, MusicImportBatchStatus.Applying) => true,
            (MusicImportBatchStatus.Paused, MusicImportBatchStatus.Running) => true,
            (MusicImportBatchStatus.Paused, MusicImportBatchStatus.CancelRequested) => true,
            (MusicImportBatchStatus.CancelRequested, MusicImportBatchStatus.Cancelled) => true,
            (MusicImportBatchStatus.Verifying, MusicImportBatchStatus.Completed) => true,
            (MusicImportBatchStatus.Verifying, MusicImportBatchStatus.CompletedWithErrors) => true,
            (MusicImportBatchStatus.Verifying, MusicImportBatchStatus.Failed) => true,
            (MusicImportBatchStatus.CompletedWithErrors, MusicImportBatchStatus.Ready) => true,
            _ => false
        };

    public static void EnsureTransition(
        MusicImportBatchStatus current,
        MusicImportBatchStatus next)
    {
        if (!CanTransition(current, next))
        {
            throw new InvalidOperationException(
                $"Cannot transition music import batch from {current} to {next}.");
        }
    }

    public static bool CanPrepareForApply(
        IReadOnlyCollection<MusicImportReviewGroup> groups) =>
        groups.Count > 0 &&
        groups.Any(group => group.Status == MusicImportReviewStatus.Confirmed) &&
        groups.All(group => group.Status is
            MusicImportReviewStatus.Confirmed or
            MusicImportReviewStatus.Applied);

    public static void EnsureReviewVersion(
        int currentVersion,
        int expectedVersion)
    {
        if (currentVersion != expectedVersion)
        {
            throw new InvalidOperationException(
                $"Review group version conflict: expected {expectedVersion}, current {currentVersion}.");
        }
    }

    public static bool IsTerminal(MusicImportItemStatus status) => status is
        MusicImportItemStatus.Imported or
        MusicImportItemStatus.Duplicate or
        MusicImportItemStatus.Skipped or
        MusicImportItemStatus.Failed or
        MusicImportItemStatus.Cancelled;

    public static bool CanRetry(
        MusicImportItemStatus status,
        bool retryable) =>
        status == MusicImportItemStatus.Failed && retryable;
}
