import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/shared/widgets/player/player_main_controls.dart';
import 'package:follow/shared/widgets/player/player_mode_control.dart';

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  final appliedModes = <PlayMode>[];

  @override
  Future<void> applyPlayMode(PlayMode mode) async {
    appliedModes.add(mode);
  }
}

void main() {
  const palette = PlayerPalette(
    primaryControl: Color(0xFF173E89),
    onPrimaryControl: Colors.white,
    secondary: Color(0xFF8A2362),
    ambient: Color(0xFF16869B),
    progress: Color(0xFF8A2362),
    glow: Color(0xFF16869B),
    scrim: Color(0xFFF7F6FC),
  );
  late _FakeAudioPlayerService audioService;
  late int playPauseCalls;
  late int previousCalls;
  late int nextCalls;
  late int queueCalls;

  setUp(() {
    audioService = _FakeAudioPlayerService();
    playPauseCalls = 0;
    previousCalls = 0;
    nextCalls = 0;
    queueCalls = 0;
  });

  Future<void> pumpControls(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioPlayerServiceProvider.overrideWithValue(audioService)],
        child: MaterialApp(
          home: Scaffold(
            body: PlayerMainControls(
              palette: palette,
              isPlaying: false,
              onPlayPause: () => playPauseCalls++,
              onPrevious: () => previousCalls++,
              onNext: () => nextCalls++,
              onShowQueue: () => queueCalls++,
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

  testWidgets('primary transport uses the guarded control pair', (
    tester,
  ) async {
    await pumpControls(tester);

    final control = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('player-primary-control')),
    );
    final decoration = control.decoration as BoxDecoration;
    expect(decoration.color, palette.primaryControl);
    expect(
      decoration.boxShadow?.single.color,
      palette.glow.withValues(alpha: 0.36),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
      palette.onPrimaryControl,
    );
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

    for (final tooltip in ['播放模式：顺序播放', '上一首', '播放', '下一首', '当前播放队列']) {
      expect(
        tester.getSize(find.byTooltip(tooltip)).shortestSide,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('transport stays centered between mode and queue actions', (
    tester,
  ) async {
    await pumpControls(tester);

    final controlsCenter = tester.getCenter(find.byType(PlayerMainControls)).dx;
    final previousX = tester.getCenter(find.byTooltip('上一首')).dx;
    final playX = tester.getCenter(find.byTooltip('播放')).dx;
    final nextX = tester.getCenter(find.byTooltip('下一首')).dx;
    final modeX = tester.getCenter(find.byTooltip('播放模式：顺序播放')).dx;
    final queueX = tester.getCenter(find.byTooltip('当前播放队列')).dx;

    expect(playX, closeTo(controlsCenter, 0.01));
    expect((previousX + nextX) / 2, closeTo(controlsCenter, 0.01));
    expect(modeX, lessThan(previousX));
    expect(queueX, greaterThan(nextX));

    await tester.tap(find.byTooltip('当前播放队列'));
    expect(queueCalls, 1);
  });

  testWidgets(
    'compact 360dp controls keep the mode popup inside the viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpControls(tester);
      await tester.tap(find.byTooltip('播放模式：顺序播放'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final mode = find.byTooltip('播放模式：随机播放');
      final popup = find.byKey(playerModePopupKey);
      expect(tester.getSize(popup).width, 112);
      expect(tester.getRect(popup).left, closeTo(8, 0.01));
      expect(
        tester.getCenter(popup).dx,
        greaterThan(tester.getCenter(mode).dx),
      );

      for (final tooltip in ['播放模式：随机播放', '上一首', '下一首', '当前播放队列']) {
        expect(tester.getSize(find.byTooltip(tooltip)), const Size.square(48));
      }
      expect(tester.getSize(find.byTooltip('播放')), const Size.square(56));
      expect(tester.getCenter(find.byTooltip('播放')).dx, closeTo(180, 0.01));
    },
  );

  for (final width in [360.0, 390.0]) {
    testWidgets('$width dp uses five equal slots with breathing room', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpControls(tester);
      final controls = [
        find.byTooltip('播放模式：顺序播放'),
        find.byTooltip('上一首'),
        find.byTooltip('播放'),
        find.byTooltip('下一首'),
        find.byTooltip('当前播放队列'),
      ];
      final centers = controls
          .map((finder) => tester.getCenter(finder).dx)
          .toList();
      final steps = <double>[
        for (var index = 1; index < centers.length; index++)
          centers[index] - centers[index - 1],
      ];
      for (final step in steps.skip(1)) {
        expect(step, closeTo(steps.first, 0.01));
      }

      for (var index = 1; index < controls.length; index++) {
        final gap =
            tester.getRect(controls[index]).left -
            tester.getRect(controls[index - 1]).right;
        expect(gap, greaterThanOrEqualTo(10));
      }
      expect(tester.getSize(controls[2]), const Size.square(56));
      for (final control in [...controls.take(2), ...controls.skip(3)]) {
        expect(tester.getSize(control), const Size.square(48));
      }
    });
  }
}
