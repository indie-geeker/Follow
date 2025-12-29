namespace Follow.Shared.DTOs;

public record PlaylistDto(
    Guid Id,
    string Name,
    string? Description,
    string? CoverUrl,
    bool IsPublic,
    int TrackCount,
    DateTime CreatedAt
);

public record PlaylistDetailDto(
    Guid Id,
    string Name,
    string? Description,
    string? CoverUrl,
    bool IsPublic,
    List<TrackDto> Tracks,
    DateTime CreatedAt
);

public record CreatePlaylistRequest(string Name, string? Description, bool IsPublic = false);
public record UpdatePlaylistRequest(string Name, string? Description, bool IsPublic);
public record AddTrackToPlaylistRequest(Guid TrackId);
