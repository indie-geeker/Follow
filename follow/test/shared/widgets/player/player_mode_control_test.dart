import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/player/player_mode_control.dart';

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  final appliedModes = <PlayMode>[];

  @override
  Future<void> applyPlayMode(PlayMode mode) async {
    appliedModes.add(mode);
  }
}

void main() {
  late _FakeAudioPlayerService audioService;

  setUp(() => audioService = _FakeAudioPlayerService());

  Future<void> pumpControl(
    WidgetTester tester, {
    Alignment alignment = Alignment.bottomLeft,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioPlayerServiceProvider.overrideWithValue(audioService)],
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: alignment,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: PlayerModeControl(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mode button cycles and shows all modes with one check', (
    tester,
  ) async {
    await pumpControl(tester);

    await tester.tap(find.byTooltip('播放模式：顺序播放'));
    await tester.pump();

    expect(find.byKey(playerModePopupKey), findsOneWidget);
    expect(find.text('列表播放'), findsOneWidget);
    expect(find.text('随机模式'), findsOneWidget);
    expect(find.text('单曲循环'), findsOneWidget);
    expect(
      find.byKey(playerModePopupCheckKey(PlayMode.sequence)),
      findsNothing,
    );
    expect(
      find.byKey(playerModePopupCheckKey(PlayMode.shuffle)),
      findsOneWidget,
    );
    expect(find.byKey(playerModePopupCheckKey(PlayMode.single)), findsNothing);
    expect(find.byTooltip('播放模式：随机播放'), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
  });

  testWidgets('popup items select directly and restart the timeout', (
    tester,
  ) async {
    await pumpControl(tester);
    await tester.tap(find.byTooltip('播放模式：顺序播放'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    await tester.tap(find.byKey(playerModePopupItemKey(PlayMode.single)));
    await tester.pump();

    expect(find.byKey(playerModePopupKey), findsOneWidget);
    expect(
      find.byKey(playerModePopupCheckKey(PlayMode.single)),
      findsOneWidget,
    );
    expect(find.byTooltip('播放模式：单曲循环'), findsOneWidget);
    expect(audioService.appliedModes, [PlayMode.shuffle, PlayMode.single]);

    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byKey(playerModePopupKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(playerModePopupKey), findsNothing);
  });

  testWidgets('repeated mode-button taps restart the timeout', (tester) async {
    await pumpControl(tester);
    await tester.tap(find.byTooltip('播放模式：顺序播放'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    await tester.tap(find.byTooltip('播放模式：随机播放'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.byKey(playerModePopupKey), findsOneWidget);
    expect(
      find.byKey(playerModePopupCheckKey(PlayMode.single)),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byKey(playerModePopupKey), findsNothing);
  });

  testWidgets('popup is centered above the mode button with 48dp items', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpControl(tester, alignment: Alignment.bottomCenter);
    await tester.tap(find.byTooltip('播放模式：顺序播放'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(
      tester.getCenter(find.byKey(playerModePopupKey)).dx,
      closeTo(tester.getCenter(find.byKey(playerModeButtonAnchorKey)).dx, 1),
    );
    for (final mode in PlayMode.values) {
      expect(
        tester.getSize(find.byKey(playerModePopupItemKey(mode))).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(find.bySemanticsLabel('随机模式，已选择'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('left-edge popup stays fully inside a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpControl(tester);
    await tester.tap(find.byTooltip('播放模式：顺序播放'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    final popupRect = tester.getRect(find.byKey(playerModePopupKey));
    expect(popupRect.width, 112);
    expect(popupRect.left, greaterThanOrEqualTo(8));
    expect(popupRect.right, lessThanOrEqualTo(352));
    expect(find.text('列表播放'), findsOneWidget);
    expect(find.text('随机模式'), findsOneWidget);
    expect(find.text('单曲循环'), findsOneWidget);
  });
}
