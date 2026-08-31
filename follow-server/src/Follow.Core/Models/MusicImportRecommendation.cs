namespace Follow.Core.Models;

public sealed record MusicImportRecommendationCandidate(
    Guid CandidateId,
    string RelativePath,
    AudioQualityFacts Quality,
    int MetadataCompleteness,
    int SourceStability);

public sealed record MusicImportRecommendation(
    Guid CandidateId,
    string Explanation,
    IReadOnlyList<string> ComparedFacts);
