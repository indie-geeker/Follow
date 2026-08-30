using Follow.Core.Entities;
using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

public interface IMusicImportService
{
    Task<MusicImportBatchDto> CreateBatchAsync(
        Guid requestedByUserId,
        CreateMusicImportRequest request,
        CancellationToken cancellationToken = default);

    Task<MusicImportBatchPageDto> GetBatchesAsync(
        int page = 1,
        int pageSize = 20,
        MusicImportBatchStatus? status = null,
        CancellationToken cancellationToken = default);

    Task<MusicImportBatchDto?> GetBatchAsync(
        Guid batchId,
        CancellationToken cancellationToken = default);

    Task<MusicImportItemPageDto?> GetItemsAsync(
        Guid batchId,
        int page = 1,
        int pageSize = 50,
        MusicImportItemStatus? status = null,
        CancellationToken cancellationToken = default);

    Task<MusicImportBatchDto?> StartAsync(Guid batchId, CancellationToken cancellationToken = default);
    Task<MusicImportBatchDto?> PauseAsync(Guid batchId, CancellationToken cancellationToken = default);
    Task<MusicImportBatchDto?> ResumeAsync(Guid batchId, CancellationToken cancellationToken = default);
    Task<MusicImportBatchDto?> CancelAsync(Guid batchId, CancellationToken cancellationToken = default);
    Task<MusicImportBatchDto?> RetryFailuresAsync(Guid batchId, CancellationToken cancellationToken = default);
}
