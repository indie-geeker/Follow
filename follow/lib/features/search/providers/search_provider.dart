import 'package:flutter_riverpod/legacy.dart';

import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/api_provider.dart';
import 'package:follow/data/providers/search_debounce.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

/// Holds the current search query globally.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Fetch tracks for the popup search (limited results)
@riverpod
Future<List<Track>> popupSearchTracks(Ref ref, String query) async {
  final normalizedQuery = query.trim();
  if (normalizedQuery.isEmpty) return [];
  if (!await waitForSearchDebounce(ref)) return [];

  // We can use the existing getTracks with a small pageSize
  final response = await ref
      .read(apiServiceProvider)
      .getTracks(search: normalizedQuery, pageSize: 10, page: 1);
  return response.tracks;
}
