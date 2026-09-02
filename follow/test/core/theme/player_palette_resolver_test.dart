import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette_resolver.dart';

void main() {
  late int extractionCount;

  PlayerPaletteResolver resolver({
    int capacity = 64,
    bool throwDuringExtraction = false,
  }) {
    return PlayerPaletteResolver(
      capacity: capacity,
      imageProviderFactory: (_) => const AssetImage('test-cover'),
      extractor: (_, brightness) async {
        extractionCount++;
        if (throwDuringExtraction) throw StateError('bad image');
        await Future<void>.delayed(Duration.zero);
        return ColorScheme.fromSeed(
          seedColor: brightness == Brightness.dark
              ? const Color(0xFF64D8FF)
              : const Color(0xFF264E9A),
          brightness: brightness,
          contrastLevel: 0.5,
        );
      },
    );
  }

  setUp(() => extractionCount = 0);

  test(
    'deduplicates concurrent extraction for the same cover and theme',
    () async {
      final subject = resolver();
      final cover = Uri.parse('https://example.test/covers/one.jpg');

      final results = await Future.wait([
        subject.resolve(
          coverUri: cover,
          brightness: Brightness.light,
          tokens: FollowThemeTokens.light,
        ),
        subject.resolve(
          coverUri: cover,
          brightness: Brightness.light,
          tokens: FollowThemeTokens.light,
        ),
      ]);

      expect(extractionCount, 1);
      expect(results[0], results[1]);
    },
  );

  test('keeps light and dark extraction results distinct', () async {
    final subject = resolver();
    final cover = Uri.parse('https://example.test/covers/one.jpg');

    final light = await subject.resolve(
      coverUri: cover,
      brightness: Brightness.light,
      tokens: FollowThemeTokens.light,
    );
    final dark = await subject.resolve(
      coverUri: cover,
      brightness: Brightness.dark,
      tokens: FollowThemeTokens.dark,
    );

    expect(extractionCount, 2);
    expect(light, isNot(dark));
  });

  test('bounds the least-recently-used cache to 64 entries', () async {
    final subject = resolver();
    for (var index = 0; index < 65; index++) {
      await subject.resolve(
        coverUri: Uri.parse('https://example.test/covers/$index.jpg'),
        brightness: Brightness.light,
        tokens: FollowThemeTokens.light,
      );
    }
    await subject.resolve(
      coverUri: Uri.parse('https://example.test/covers/0.jpg'),
      brightness: Brightness.light,
      tokens: FollowThemeTokens.light,
    );

    expect(extractionCount, 66);
  });

  test(
    'uses deterministic fallback for missing or unreadable covers',
    () async {
      final subject = resolver(throwDuringExtraction: true);

      final missing = await subject.resolve(
        coverUri: null,
        brightness: Brightness.dark,
        tokens: FollowThemeTokens.dark,
      );
      final unreadable = await subject.resolve(
        coverUri: Uri.parse('https://example.test/covers/bad.jpg'),
        brightness: Brightness.dark,
        tokens: FollowThemeTokens.dark,
      );

      expect(missing, unreadable);
      expect(missing.primaryControl, FollowThemeTokens.dark.brandPrimary);
    },
  );
}
