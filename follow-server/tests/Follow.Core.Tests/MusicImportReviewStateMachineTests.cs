using Follow.Core.Entities;
using Follow.Core.Services;

namespace Follow.Core.Tests;

public class MusicImportReviewStateMachineTests
{
    [Fact]
    public void Batch_CannotSkipReadyToApply()
    {
        Assert.False(MusicImportStateMachine.CanTransition(
            MusicImportBatchStatus.AwaitingReview,
            MusicImportBatchStatus.Applying));
        Assert.True(MusicImportStateMachine.CanTransition(
            MusicImportBatchStatus.AwaitingReview,
            MusicImportBatchStatus.ReadyToApply));
        Assert.True(MusicImportStateMachine.CanTransition(
            MusicImportBatchStatus.ReadyToApply,
            MusicImportBatchStatus.Applying));
    }

    [Theory]
    [InlineData(MusicImportReviewStatus.Open)]
    [InlineData(MusicImportReviewStatus.Deferred)]
    [InlineData(MusicImportReviewStatus.Locked)]
    [InlineData(MusicImportReviewStatus.Conflict)]
    [InlineData(MusicImportReviewStatus.Failed)]
    public void Batch_CannotPrepareForApplyWhenAnyGroupIsNotConfirmed(
        MusicImportReviewStatus unresolvedStatus)
    {
        var groups = new[]
        {
            new MusicImportReviewGroup { Status = MusicImportReviewStatus.Confirmed },
            new MusicImportReviewGroup { Status = unresolvedStatus }
        };

        Assert.False(MusicImportStateMachine.CanPrepareForApply(groups));
    }

    [Fact]
    public void Batch_CanPrepareForApplyOnlyWhenEveryGroupIsExplicitlyConfirmed()
    {
        var groups = new[]
        {
            new MusicImportReviewGroup { Status = MusicImportReviewStatus.Confirmed },
            new MusicImportReviewGroup { Status = MusicImportReviewStatus.Confirmed }
        };

        Assert.True(MusicImportStateMachine.CanPrepareForApply(groups));
    }

    [Fact]
    public void Batch_CanPrepareRemainingConfirmedGroupsAfterEarlierGroupsWereApplied()
    {
        var groups = new[]
        {
            new MusicImportReviewGroup { Status = MusicImportReviewStatus.Applied },
            new MusicImportReviewGroup { Status = MusicImportReviewStatus.Confirmed }
        };

        Assert.True(MusicImportStateMachine.CanPrepareForApply(groups));
        Assert.False(MusicImportStateMachine.CanPrepareForApply([
            new MusicImportReviewGroup { Status = MusicImportReviewStatus.Applied }
        ]));
    }

    [Fact]
    public void RecommendationDoesNotCountAsConfirmation()
    {
        var group = new MusicImportReviewGroup
        {
            Status = MusicImportReviewStatus.Open,
            RecommendedItemId = Guid.NewGuid(),
            RecommendationExplanation = "lossless"
        };

        Assert.False(MusicImportStateMachine.CanPrepareForApply([group]));
    }

    [Fact]
    public void EmptyReviewSetCannotPrepareForApply()
    {
        Assert.False(MusicImportStateMachine.CanPrepareForApply([]));
    }

    [Fact]
    public void StaleReviewVersionIsRejected()
    {
        var exception = Assert.Throws<InvalidOperationException>(() =>
            MusicImportStateMachine.EnsureReviewVersion(
                currentVersion: 4,
                expectedVersion: 3));

        Assert.Contains("version", exception.Message, StringComparison.OrdinalIgnoreCase);
    }
}
