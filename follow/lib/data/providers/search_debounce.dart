import 'package:riverpod_annotation/riverpod_annotation.dart';

const searchRequestDebounceDuration = Duration(milliseconds: 300);

Future<bool> waitForSearchDebounce(Ref ref) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(searchRequestDebounceDuration);
  return !disposed;
}
