namespace Follow.Core.Entities;

public enum MusicImportSourceKind
{
    MountedDirectory,
    BrowserStaging
}

public enum MusicImportReviewStatus
{
    Open,
    Confirmed,
    Locked,
    Applied,
    Deferred,
    Conflict,
    Failed
}

public enum MusicImportDecisionKind
{
    CreateTrack,
    ReplaceExistingTrack,
    KeepExistingTrack,
    TreatAsSeparateRecording,
    RejectDuplicate,
    Defer
}

public enum MusicImportMatchKind
{
    None,
    ExactSha256,
    AcousticFingerprint,
    UserSeparated
}
