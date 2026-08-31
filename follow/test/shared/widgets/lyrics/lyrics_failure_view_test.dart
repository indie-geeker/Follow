import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/data/services/lyrics_service.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_failure_view.dart';

class _FailingLyricsService extends Fake implements LyricsService {
  int calls = 0;

  @override
  Future<List<Never>> fetchLyrics(String trackId) async {
    calls++;
    throw Exception('network unavailable');
  }
}

class _LyricsFailureHarness extends ConsumerWidget {
  const _LyricsFailureHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(currentTrackLyricsProvider)
        .when(
          data: (_) => const Text('loaded'),
          loading: () => const CircularProgressIndicator(),
          error: (_, _) => const LyricsFailureView(),
        );
  }
}

void main() {
  testWidgets('retry invalidates and reloads the current track lyrics', (
    tester,
  ) async {
    final service = _FailingLyricsService();
    const track = Track(
      id: 'track-1',
      title: 'Song',
      lyricsUrl: '/lyrics/track-1.lrc',
    );

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          currentTrackProvider.overrideWithValue(track),
          lyricsServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: Scaffold(body: _LyricsFailureHarness())),
      ),
    );
    await tester.pump();

    expect(find.text('歌词加载失败，请重试'), findsOneWidget);
    expect(find.byTooltip('重新加载歌词'), findsOneWidget);
    final callsBeforeRetry = service.calls;

    await tester.tap(find.byTooltip('重新加载歌词'));
    await tester.pump();
    await tester.pump();

    expect(service.calls, greaterThan(callsBeforeRetry));
  });
}
