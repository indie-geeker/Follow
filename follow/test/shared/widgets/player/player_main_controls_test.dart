import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/player/player_main_controls.dart';

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  final appliedModes = <PlayMode>[];

  @override
  Future<void> applyPlayMode(PlayMode mode) async {
    appliedModes.add(mode);
  }
}

void main() {
  late _FakeAudioPlayerService audioService;
  late int playPauseCalls;
  late int previousCalls;
  late int nextCalls;

  setUp(() {
    audioService = _FakeAudioPlayerService();
    playPauseCalls = 0;
    previousCalls = 0;
    nextCalls = 0;
  });

  Future<void> pumpControls(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioPlayerServiceProvider.overrideWithValue(audioService)],
        child: MaterialApp(
          home: Scaffold(
            body: PlayerMainControls(
              isPlaying: false,
              onPlayPause: () => playPauseCalls++,
              onPrevious: () => previousCalls++,
              onNext: () => nextCalls++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('one mode button cycles sequence, shuffle and single', (
    tester,
  ) async {
    await pumpControls(tester);

    expect(find.byTooltip('播放模式：顺序播放'), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsNothing);

    await tester.tap(find.byTooltip('播放模式：顺序播放'));
    await tester.pump();
    expect(find.byTooltip('播放模式：随机播放'), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('播放模式：随机播放'));
    await tester.pump();
    expect(find.byTooltip('播放模式：单曲循环'), findsOneWidget);
    expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('播放模式：单曲循环'));
    await tester.pump();
    expect(find.byTooltip('播放模式：顺序播放'), findsOneWidget);
    expect(audioService.appliedModes, [
      PlayMode.shuffle,
      PlayMode.single,
      PlayMode.sequence,
    ]);
  });

  testWidgets('playback actions delegate once and remain touch friendly', (
    tester,
  ) async {
    await pumpControls(tester);

    for (final tooltip in ['上一首', '播放', '下一首']) {
      await tester.tap(find.byTooltip(tooltip));
    }
    await tester.pump();

    expect(previousCalls, 1);
    expect(playPauseCalls, 1);
    expect(nextCalls, 1);

    for (final tooltip in ['播放模式：顺序播放', '上一首', '播放', '下一首']) {
      expect(
        tester.getSize(find.byTooltip(tooltip)).shortestSide,
        greaterThanOrEqualTo(48),
      );
    }
  });
}
