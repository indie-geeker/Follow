import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/features/home/widgets/home_aurora_header.dart';

const _brandPalette = PlayerPalette(
  primaryControl: Color(0xFF5B46F0),
  onPrimaryControl: Colors.white,
  secondary: Color(0xFFB62D71),
  ambient: Color(0xFF2A8EAF),
  progress: Color(0xFF5B46F0),
  glow: Color(0xFF2A8EAF),
  scrim: Color(0xFFF7F6FC),
);

const _coverPalette = PlayerPalette(
  primaryControl: Color(0xFF8B4A2F),
  onPrimaryControl: Colors.white,
  secondary: Color(0xFFC77D55),
  ambient: Color(0xFF6C8796),
  progress: Color(0xFFC77D55),
  glow: Color(0xFF6C8796),
  scrim: Color(0xFFF7F6FC),
);

Widget _harness({
  PlayerPalette palette = _brandPalette,
  bool usesBrandFallback = true,
  double collapseProgress = 0,
}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: Brightness.light,
      extensions: const [FollowThemeTokens.light],
    ),
    home: Scaffold(
      body: SizedBox(
        height: 180,
        child: HomeAuroraHeader(
          palette: palette,
          usesBrandFallback: usesBrandFallback,
          collapseProgress: collapseProgress,
          title: '你好, indiegeeker',
          subtitle: '开始享受音乐吧',
          leading: const Text('Follow Music'),
          trailing: const CircleAvatar(child: Text('I')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('first launch renders the brand record aurora without an image', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    expect(find.byKey(homeHeroKey), findsOneWidget);
    expect(find.byKey(homeHeroBrandFallbackKey), findsOneWidget);
    expect(find.byKey(homeHeroGroovesKey), findsOneWidget);
    expect(find.byKey(homeHeroWaveformKey), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('recent artwork palette preserves the same header geometry', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    final brandRect = tester.getRect(find.byKey(homeHeroKey));

    await tester.pumpWidget(
      _harness(palette: _coverPalette, usesBrandFallback: false),
    );
    await tester.pump();

    expect(tester.getRect(find.byKey(homeHeroKey)), brandRect);
    expect(find.byKey(homeHeroBrandFallbackKey), findsNothing);
    expect(find.byKey(homeHeroCoverPaletteKey), findsOneWidget);
  });

  testWidgets('hero tint dissolves into the shared page atmosphere', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    final tint = tester.widget<DecoratedBox>(
      find.byKey(homeHeroBrandFallbackKey),
    );
    final gradient =
        (tint.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors.last.a, 0);
  });

  testWidgets(
    'collapse progress fades artwork but keeps complete greeting semantics',
    (tester) async {
      await tester.pumpWidget(_harness(collapseProgress: 1));

      final artworkOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(homeHeroArtworkKey),
          matching: find.byType(Opacity),
        ),
      );
      expect(artworkOpacity.opacity, 0);
      expect(find.bySemanticsLabel('你好, indiegeeker。开始享受音乐吧'), findsOneWidget);
      expect(find.byKey(homeHeroGreetingKey), findsOneWidget);
    },
  );
}
