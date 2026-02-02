import 'package:dio/dio.dart';
import 'package:follow/data/models/user.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_client.dart';

/// API Service - Plain Dio implementation
class ApiService {
  final Dio _dio;

  ApiService() : _dio = ApiClient.instance;

  // ============ Auth ============

  dynamic _getData(dynamic responseData) {
    if (responseData is Map<String, dynamic> &&
        responseData.containsKey('code') &&
        responseData.containsKey('data')) {
      final code = responseData['code'];
      if (code == 0) {
        return responseData['data'];
      }
      throw Exception(responseData['message'] ?? 'API Error: $code');
    }
    return responseData;
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _dio.post('/api/auth/login', data: request.toJson());
    return AuthResponse.fromJson(_getData(response.data));
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await _dio.post('/api/auth/register', data: request.toJson());
    return AuthResponse.fromJson(_getData(response.data));
  }

  Future<User> getCurrentUser() async {
    final response = await _dio.get('/api/auth/me');
    return User.fromJson(_getData(response.data));
  }

  // ============ Tracks ============

  Future<TrackListResponse> getTracks({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final response = await _dio.get('/api/tracks', queryParameters: {
      'page': page,
      'pageSize': pageSize,
      if (search != null) 'search': search,
    });
    return TrackListResponse.fromJson(response.data);
  }

  Future<Track> getTrackById(String id) async {
    final response = await _dio.get('/api/tracks/$id');
    return Track.fromJson(response.data);
  }

  String getStreamUrl(String trackId) {
    return '${_dio.options.baseUrl}/api/tracks/$trackId/stream';
  }

  // ============ Artists ============

  Future<List<Artist>> getArtists() async {
    final response = await _dio.get('/api/artists');
    return (response.data as List).map((e) => Artist.fromJson(e)).toList();
  }

  Future<Artist> getArtistById(String id) async {
    final response = await _dio.get('/api/artists/$id');
    return Artist.fromJson(response.data);
  }

  // ============ Albums ============

  Future<List<Album>> getAlbums() async {
    final response = await _dio.get('/api/albums');
    return (response.data as List).map((e) => Album.fromJson(e)).toList();
  }

  Future<Album> getAlbumById(String id) async {
    final response = await _dio.get('/api/albums/$id');
    return Album.fromJson(response.data);
  }

  // ============ Playlists ============

  Future<List<Playlist>> getPlaylists() async {
    final response = await _dio.get('/api/playlists');
    return (response.data as List).map((e) => Playlist.fromJson(e)).toList();
  }

  Future<PlaylistDetail> getPlaylistById(String id) async {
    final response = await _dio.get('/api/playlists/$id');
    return PlaylistDetail.fromJson(response.data);
  }

  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final response = await _dio.post('/api/playlists', data: {
      'name': name,
      if (description != null) 'description': description,
    });
    return Playlist.fromJson(response.data);
  }

  Future<void> deletePlaylist(String id) async {
    await _dio.delete('/api/playlists/$id');
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    await _dio.post('/api/playlists/$playlistId/tracks', data: {
      'trackId': trackId,
    });
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _dio.delete('/api/playlists/$playlistId/tracks/$trackId');
  }

  // ============ Favorites ============

  Future<List<Track>> getFavorites() async {
    final response = await _dio.get('/api/user/favorites');
    return (response.data as List).map((e) => Track.fromJson(e)).toList();
  }

  Future<void> addToFavorites(String trackId) async {
    await _dio.post('/api/user/favorites/$trackId');
  }

  Future<void> removeFromFavorites(String trackId) async {
    await _dio.delete('/api/user/favorites/$trackId');
  }

  Future<bool> checkFavorite(String trackId) async {
    final response = await _dio.get('/api/user/favorites/$trackId/check');
    return response.data['isFavorite'] ?? false;
  }

  // ============ History ============

  Future<List<Track>> getHistory() async {
    final response = await _dio.get('/api/user/history');
    return (response.data as List).map((e) {
      // Server returns {track: TrackDto, playedAt: ..., playDurationSeconds: ...}
      return Track.fromJson(e['track']);
    }).toList();
  }

  Future<void> addToHistory(String trackId) async {
    await _dio.post('/api/user/history', data: {'trackId': trackId});
  }
}

class TrackListResponse {
  final List<Track> tracks;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  TrackListResponse({
    required this.tracks,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory TrackListResponse.fromJson(Map<String, dynamic> json) {
    return TrackListResponse(
      tracks: (json['tracks'] as List?)?.map((e) => Track.fromJson(e)).toList() ?? [],
      totalCount: json['totalCount'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['pageSize'] ?? 20,
      totalPages: json['totalPages'] ?? 1,
    );
  }
}
