import 'package:flutter_riverpod/legacy.dart';

import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

/// Holds the current search query globally.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Fetch tracks for the popup search (limited results)
@riverpod
Future<List<Track>> popupSearchTracks(Ref ref, String query) async {
  if (query.isEmpty) return [];

  final apiService = ApiService();
  // We can use the existing getTracks with a small pageSize
  final response = await apiService.getTracks(
    search: query,
    pageSize: 10,
    page: 1,
  );
  return response.tracks;
}
