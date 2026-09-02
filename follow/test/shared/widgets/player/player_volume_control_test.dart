import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/shared/widgets/player/player_volume_control.dart';

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  final volumes = <double>[];

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
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
  test('mute preserves and restores the last audible volume', () {
    expect(nextMuteVolume(current: 0.65, lastAudible: 1.0), (0.0, 0.65));
    expect(nextMuteVolume(current: 0.0, lastAudible: 0.65), (0.65, 0.65));
  });

  testWidgets('slider and mute controls delegate app volume at 320dp', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    final audioService = _FakeAudioPlayerService();
    var interactionStarts = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audioService),
          playerVolumeProvider.overrideWithValue(const AsyncData(0.65)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PlayerVolumeControl(
              palette: palette,
              onInteractionStart: () => interactionStarts++,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0.65);
    expect(
      tester
          .widget<SliderTheme>(find.byType(SliderTheme))
          .data
          .activeTrackColor,
      palette.secondary,
    );
    expect(find.byTooltip('静音'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    tester.widget<Slider>(find.byType(Slider)).onChangeStart!(0.65);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.4);
    await tester.pump();
    expect(interactionStarts, 1);
    expect(audioService.volumes.last, 0.4);

    await tester.tap(find.byTooltip('静音'));
    await tester.pump();
    expect(interactionStarts, 2);
    expect(audioService.volumes.last, 0.0);
    expect(find.byTooltip('取消静音'), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('取消静音'));
    await tester.pump();
    expect(interactionStarts, 3);
    expect(audioService.volumes.last, 0.4);
    expect(find.byTooltip('静音'), findsOneWidget);

    expect(
      tester.getSize(find.byTooltip('静音')).shortestSide,
      greaterThanOrEqualTo(48),
    );
  });
}
