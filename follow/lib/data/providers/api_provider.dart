import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/services/api/api_service.dart';

part 'api_provider.g.dart';

/// ApiService provider - provides a singleton instance of ApiService
@Riverpod(keepAlive: true)
ApiService apiService(Ref ref) => ApiService();
