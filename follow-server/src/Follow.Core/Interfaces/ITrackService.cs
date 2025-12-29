using Follow.Core.Entities;
using Follow.Shared.DTOs;

namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for track management service
/// </summary>
public interface ITrackService
{
    /// <summary>
    /// Upload and process a new track
    /// </summary>
    Task<TrackDto> UploadTrackAsync(Stream fileStream, string fileName, string contentType);

    /// <summary>
    /// Get all tracks with pagination
    /// </summary>
    Task<(List<TrackDto> Tracks, int TotalCount)> GetTracksAsync(int page = 1, int pageSize = 20, string? search = null);

    /// <summary>
    /// Get a track by ID
    /// </summary>
    Task<TrackDto?> GetTrackByIdAsync(Guid id);

    /// <summary>
    /// Update track metadata
    /// </summary>
    Task<TrackDto?> UpdateTrackAsync(Guid id, UpdateTrackRequest request);

    /// <summary>
    /// Delete a track
    /// </summary>
    Task<bool> DeleteTrackAsync(Guid id);

    /// <summary>
    /// Get audio stream for playback
    /// </summary>
    Task<(Stream? Stream, string? ContentType, long? Length)> GetTrackStreamAsync(Guid id);

    /// <summary>
    /// Upload cover image for a track
    /// </summary>
    Task<string> UploadTrackCoverAsync(Guid trackId, Stream fileStream, string fileName, string contentType);

    /// <summary>
    /// Upload lyrics file for a track
    /// </summary>
    Task<string> UploadTrackLyricsAsync(Guid trackId, Stream fileStream, string fileName, string contentType);

    /// <summary>
    /// Get lyrics stream for a track
    /// </summary>
    Task<(Stream? Stream, string? ContentType)?> GetLyricsStreamAsync(Guid trackId);
}

public record UpdateTrackRequest(string? Title, Guid? ArtistId, Guid? AlbumId, string? CoverUrl, string? LyricsUrl);
