using Follow.Core.Entities;
using Follow.Core.Services;

namespace Follow.Core.Tests;

public class MusicImportStateMachineTests
{
    [Fact]
    public void Batch_HappyPath_AllowsInitializationLifecycle()
    {
        var lifecycle = new[]
        {
            MusicImportBatchStatus.Pending,
            MusicImportBatchStatus.Scanning,
            MusicImportBatchStatus.Ready,
            MusicImportBatchStatus.Analyzing,
            MusicImportBatchStatus.Grouping,
            MusicImportBatchStatus.AwaitingReview,
            MusicImportBatchStatus.ReadyToApply,
            MusicImportBatchStatus.Applying,
            MusicImportBatchStatus.Verifying,
            MusicImportBatchStatus.Completed
        };

        for (var index = 0; index < lifecycle.Length - 1; index++)
        {
            Assert.True(MusicImportStateMachine.CanTransition(
                lifecycle[index],
                lifecycle[index + 1]));
        }
    }

    [Fact]
    public void Batch_PauseResumeAndCancel_AreExplicitTransitions()
    {
        var resumableStatuses = new[]
        {
            MusicImportBatchStatus.Analyzing,
            MusicImportBatchStatus.Grouping,
            MusicImportBatchStatus.AwaitingReview,
            MusicImportBatchStatus.Applying
        };

        foreach (var resumableStatus in resumableStatuses)
        {
            Assert.True(MusicImportStateMachine.CanTransition(
                resumableStatus,
                MusicImportBatchStatus.PauseRequested));
            Assert.True(MusicImportStateMachine.CanTransition(
                MusicImportBatchStatus.Paused,
                resumableStatus));
            Assert.True(MusicImportStateMachine.CanTransition(
                resumableStatus,
                MusicImportBatchStatus.CancelRequested));
        }

        Assert.True(MusicImportStateMachine.CanTransition(
            MusicImportBatchStatus.PauseRequested,
            MusicImportBatchStatus.Paused));
        Assert.True(MusicImportStateMachine.CanTransition(
            MusicImportBatchStatus.Paused,
            MusicImportBatchStatus.CancelRequested));
        Assert.True(MusicImportStateMachine.CanTransition(
            MusicImportBatchStatus.CancelRequested,
            MusicImportBatchStatus.Cancelled));
    }

    [Fact]
    public void Batch_CompletedWithErrors_CanReturnToReadyForExplicitRetry()
    {
        Assert.True(MusicImportStateMachine.CanTransition(
            MusicImportBatchStatus.CompletedWithErrors,
            MusicImportBatchStatus.Ready));
        Assert.False(MusicImportStateMachine.CanTransition(
            MusicImportBatchStatus.Completed,
            MusicImportBatchStatus.Ready));
    }

    [Theory]
    [InlineData(MusicImportBatchStatus.Completed)]
    [InlineData(MusicImportBatchStatus.CompletedWithErrors)]
    [InlineData(MusicImportBatchStatus.Cancelled)]
    [InlineData(MusicImportBatchStatus.Failed)]
    public void Batch_TerminalStates_RejectFurtherTransitions(
        MusicImportBatchStatus terminalStatus)
    {
        Assert.False(MusicImportStateMachine.CanTransition(
            terminalStatus,
            MusicImportBatchStatus.Running));
        Assert.Throws<InvalidOperationException>(() =>
            MusicImportStateMachine.EnsureTransition(
                terminalStatus,
                MusicImportBatchStatus.Running));
    }

    [Theory]
    [InlineData(MusicImportItemStatus.Imported)]
    [InlineData(MusicImportItemStatus.Duplicate)]
    [InlineData(MusicImportItemStatus.Skipped)]
    [InlineData(MusicImportItemStatus.Failed)]
    [InlineData(MusicImportItemStatus.Cancelled)]
    public void Item_TerminalStates_AreReportedAsTerminal(
        MusicImportItemStatus status)
    {
        Assert.True(MusicImportStateMachine.IsTerminal(status));
    }

    [Fact]
    public void Item_OnlyRetryableFailureCanBeRetried()
    {
        Assert.True(MusicImportStateMachine.CanRetry(
            MusicImportItemStatus.Failed,
            retryable: true));
        Assert.False(MusicImportStateMachine.CanRetry(
            MusicImportItemStatus.Failed,
            retryable: false));
        Assert.False(MusicImportStateMachine.CanRetry(
            MusicImportItemStatus.Imported,
            retryable: true));
    }
}
