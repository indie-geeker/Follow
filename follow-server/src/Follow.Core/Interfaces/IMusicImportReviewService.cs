using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

public interface IMusicImportReviewService
{
    Task<MusicImportReviewBatchDto?> GetBatchReviewAsync(
        Guid batchId,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default);

    Task<MusicImportReviewGroupDto?> GetGroupAsync(
        Guid groupId,
        CancellationToken cancellationToken = default);

    Task<MusicImportReviewGroupDto> SaveDecisionAsync(
        Guid groupId,
        Guid actingUserId,
        MusicImportReviewDecisionRequest request,
        CancellationToken cancellationToken = default);

    Task<MusicImportReviewBatchStateDto> LockBatchAsync(
        Guid batchId,
        Guid actingUserId,
        MusicImportLockRequest request,
        CancellationToken cancellationToken = default);
}

public sealed class MusicImportReviewConflictException : InvalidOperationException
{
    public MusicImportReviewConflictException(MusicImportReviewGroupDto current)
        : base("The review group changed concurrently; refresh and retry.")
    {
        Current = current;
    }

    public MusicImportReviewGroupDto Current { get; }
}
