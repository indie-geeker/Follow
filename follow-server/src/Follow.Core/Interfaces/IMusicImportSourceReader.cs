using Follow.Core.Models;

namespace Follow.Core.Interfaces;

public interface IMusicImportSourceReader
{
    Task<MusicImportSourceReadHandle> OpenReadAsync(
        MusicImportSourceSnapshot expectedSnapshot,
        CancellationToken cancellationToken = default);
}
