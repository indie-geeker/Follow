import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/network/cover_image_provider.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/player/player_aurora_background.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';

const _firstTrack = Track(
  id: 'track-1',
  title: 'First',
  coverUrl: 'covers/first.jpg',
);
const _secondTrack = Track(
  id: 'track-2',
  title: 'Second',
  coverUrl: 'covers/second.jpg',
);

PlayerPalette get _palette => PlayerPalette.fallback(
  brightness: Brightness.dark,
  tokens: FollowThemeTokens.dark,
);

Widget _harness({
  Track? track = _firstTrack,
  bool disableAnimations = false,
  ImageProvider<Object>? imageProviderOverride,
}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: Brightness.dark,
      extensions: const [FollowThemeTokens.dark],
    ),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: SizedBox.expand(
        child: PlayerAuroraBackground(
          track: track,
          palette: _palette,
          imageProviderOverride: imageProviderOverride,
          child: const Text('content'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('visible cover and atmosphere use the same normalized URI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [FollowThemeTokens.dark],
        ),
        home: Row(
          children: [
            const TrackCoverImage(track: _firstTrack, size: 72),
            Expanded(
              child: PlayerAuroraBackground(
                track: _firstTrack,
                palette: _palette,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );

    final providers = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<CachedNetworkImageProvider>()
        .toList();
    expect(providers, hasLength(2));
    expect(providers[0].url, providers[1].url);
    expect(providers[0], coverImageProviderForTrack(_firstTrack));
  });

  testWidgets('builds one blur one scrim and two palette glows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(imageProviderOverride: const AssetImage('test-cover')),
    );

    expect(find.byKey(playerBackdropBlurKey), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byKey(playerBackdropScrimKey), findsOneWidget);
    expect(find.byKey(playerBackdropPrimaryGlowKey), findsOneWidget);
    expect(find.byKey(playerBackdropAmbientGlowKey), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);
  });

  testWidgets('cover identity changes crossfade over the palette duration', (
    tester,
  ) async {
    const fakeProvider = AssetImage('test-cover');
    await tester.pumpWidget(
      _harness(track: _firstTrack, imageProviderOverride: fakeProvider),
    );
    await tester.pumpWidget(
      _harness(track: _secondTrack, imageProviderOverride: fakeProvider),
    );

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byKey(playerBackdropSwitcherKey),
    );
    expect(switcher.duration, FollowThemeTokens.dark.motionPalette);
    expect(find.byKey(playerBackdropCoverKey(_firstTrack)), findsOneWidget);
    expect(find.byKey(playerBackdropCoverKey(_secondTrack)), findsOneWidget);
  });

  testWidgets('crossfade keeps every cover layer pinned to the viewport', (
    tester,
  ) async {
    const fakeProvider = AssetImage('test-cover');
    await tester.pumpWidget(
      _harness(track: _firstTrack, imageProviderOverride: fakeProvider),
    );
    await tester.pumpWidget(
      _harness(track: _secondTrack, imageProviderOverride: fakeProvider),
    );

    final switcherFinder = find.byKey(playerBackdropSwitcherKey);
    final switcher = tester.widget<AnimatedSwitcher>(switcherFinder);
    final layout = switcher.layoutBuilder(
      const SizedBox(key: ValueKey('incoming')),
      const [SizedBox(key: ValueKey('outgoing'))],
    );
    expect(layout, isA<Stack>());
    expect((layout as Stack).fit, StackFit.expand);

    final viewport = tester.getRect(switcherFinder);
    expect(
      tester.getRect(find.byKey(playerBackdropCoverKey(_firstTrack))),
      viewport,
    );
    expect(
      tester.getRect(find.byKey(playerBackdropCoverKey(_secondTrack))),
      viewport,
    );
  });

  testWidgets('missing artwork renders brand fallback without an image', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(track: null));

    expect(find.byKey(playerBackdropFallbackKey), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('image failure resolves to the branded backdrop fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(imageProviderOverride: const AssetImage('missing-test-cover')),
    );
    await tester.pump();

    expect(find.byKey(playerBackdropImageFallbackKey), findsOneWidget);
  });

  testWidgets('reduced motion replaces cover identity without spatial motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        disableAnimations: true,
        imageProviderOverride: const AssetImage('test-cover'),
      ),
    );

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byKey(playerBackdropSwitcherKey),
    );
    expect(switcher.duration, Duration.zero);
    expect(
      find.descendant(
        of: find.byKey(playerBackdropSwitcherKey),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
  });
}
