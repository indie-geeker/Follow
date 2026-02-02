import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_service.dart';

part 'history_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<Track>> history(ref) async {
  final apiService = ApiService();
  return await apiService.getHistory();
}
