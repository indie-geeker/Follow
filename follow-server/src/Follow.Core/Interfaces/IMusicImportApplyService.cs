namespace Follow.Core.Interfaces;

public interface IMusicImportApplyService
{
    Task<MusicImportApplyResult> ApplyGroupAsync(
        Guid groupId,
        int expectedVersion,
        CancellationToken cancellationToken = default);
}

public sealed record MusicImportApplyResult(
    Guid GroupId,
    Guid TrackId,
    bool AlreadyApplied,
    IReadOnlyList<Guid>? AppliedTrackIds = null)
{
    public IReadOnlyList<Guid> TrackIds => AppliedTrackIds ?? [TrackId];
}

public sealed class MusicImportApplyConflictException : InvalidOperationException
{
    public MusicImportApplyConflictException(int currentVersion)
        : base($"Music import apply version conflict; current version is {currentVersion}.")
    {
        CurrentVersion = currentVersion;
    }

    public int CurrentVersion { get; }
}

public sealed class MusicImportApplyValidationException : IOException
{
    public MusicImportApplyValidationException(string message) : base(message)
    {
    }
}
