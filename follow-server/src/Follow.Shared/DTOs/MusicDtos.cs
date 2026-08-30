namespace Follow.Shared.DTOs;

public record TrackDto(
    Guid Id,
    string Title,
    int DurationSeconds,
    string? CoverUrl,
    string? LyricsUrl,
    int BitRate,
    string? Format,
    ArtistDto? Artist,
    AlbumDto? Album,
    DateTime CreatedAt
);

public record TrackUploadResponse(
    Guid Id,
    string Title,
    int DurationSeconds,
    string? CoverUrl
);

public record ArtistDto(
    Guid Id,
    string Name,
    string? CoverUrl,
    string? Bio
);

public record AlbumDto(
    Guid Id,
    string Title,
    int? Year,
    string? CoverUrl,
    ArtistDto? Artist
);

public record CreateArtistRequest(string Name, string? Bio);
public record UpdateArtistRequest(string Name, string? Bio);

public record CreateAlbumRequest(string Title, int? Year, Guid? ArtistId);
public record UpdateAlbumRequest(string Title, int? Year, Guid? ArtistId);
