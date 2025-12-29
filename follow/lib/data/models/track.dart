import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.freezed.dart';
part 'track.g.dart';

@freezed
abstract class Track with _$Track {
  const factory Track({
    required String id,
    required String title,
    @Default(0) int durationSeconds,
    String? coverUrl,
    String? lyricsUrl,
    @Default(0) int bitRate,
    String? format,
    Artist? artist,
    Album? album,
    DateTime? createdAt,
    @Default(false) bool isDownloaded,
    String? localPath,
  }) = _Track;

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
}

@freezed
abstract class Artist with _$Artist {
  const factory Artist({
    required String id,
    required String name,
    String? coverUrl,
    String? bio,
  }) = _Artist;

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);
}

@freezed
abstract class Album with _$Album {
  const factory Album({
    required String id,
    required String title,
    int? year,
    String? coverUrl,
    Artist? artist,
  }) = _Album;

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
}

@freezed
abstract class Playlist with _$Playlist {
  const factory Playlist({
    required String id,
    required String name,
    String? description,
    String? coverUrl,
    @Default(false) bool isPublic,
    @Default(0) int trackCount,
    DateTime? createdAt,
  }) = _Playlist;

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);
}

@freezed
abstract class PlaylistDetail with _$PlaylistDetail {
  const factory PlaylistDetail({
    required String id,
    required String name,
    String? description,
    String? coverUrl,
    @Default(false) bool isPublic,
    @Default([]) List<Track> tracks,
    DateTime? createdAt,
  }) = _PlaylistDetail;

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) =>
      _$PlaylistDetailFromJson(json);
}
