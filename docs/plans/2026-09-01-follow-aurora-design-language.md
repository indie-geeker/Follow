# Follow Aurora Design Language Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Follow's scattered Flutter styling with an approved light/dark aurora design system, illustrated SVG states, and a performant cover-adaptive glass player while preserving current playback and gesture behavior.

**Architecture:** Define immutable semantic tokens through `ThemeExtension`, then build shared aurora, glass, state, and skeleton primitives on top of those tokens. Keep cover-derived colors in a player-local palette resolver backed by Flutter's built-in `ColorScheme.fromImageProvider`, cache results by cover and brightness, and use the palette only for atmosphere and safe accents. Migrate pages incrementally behind focused tests, then remove legacy `LoginColors` and duplicate empty/error/loading implementations.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Material 3, Riverpod, `cached_network_image`, `flutter_svg` 2.2.3, Flutter widget tests, standard Flutter golden support.

---

## Execution Preconditions

The current `main` checkout is ahead of `origin/main` and contains overlapping
uncommitted player, lyric, queue, theme-adjacent, test, asset, and lock-file
changes. Do not start implementation from a clean historical `main` worktree,
because that would omit the current vinyl/gesture player that this design must
preserve.

Before Task 1:

1. Inspect `git status --short --branch` again.
2. Obtain explicit user authorization for a recoverable scoped checkpoint of
   the current player/lyrics work, or obtain explicit authorization to work in
   the existing checkout.
3. If a checkpoint is authorized, include only named current paths. Never use
   `git add -A`, never reset unrelated work, and do not include generated or
   unrelated files.
4. Create an isolated `codex/` worktree from that checkpoint by using
   `superpowers:using-git-worktrees` before changing implementation files.
5. Run all Flutter commands from `follow/` with `--no-pub` unless a task
   intentionally changes dependencies. This plan adds no package dependency.

Every commit step below is a proposed scoped checkpoint. Execute it only after
the user has authorized commits. Otherwise leave the named changes uncommitted
and report them explicitly.

### Task 1: Establish the semantic token contract

**Files:**
- Create: `follow/lib/core/theme/follow_theme_tokens.dart`
- Create: `follow/test/core/theme/follow_theme_tokens_test.dart`
- Modify: `follow/lib/core/theme/app_theme.dart`
- Modify: `follow/test/core/theme/app_theme_test.dart`

**Step 1: Write the failing token tests**

Test exact approved colors, typography roles, spacing/radius values, glass
tiers, motion durations, and the required fixed-pair contrast ratios.

```dart
test('approved text and action pairs meet WCAG AA', () {
  for (final pair in <(Color, Color)>[
    (FollowThemeTokens.light.textPrimary, FollowThemeTokens.light.background),
    (FollowThemeTokens.light.onBrandPrimary, FollowThemeTokens.light.brandPrimary),
    (FollowThemeTokens.dark.textPrimary, FollowThemeTokens.dark.background),
    (FollowThemeTokens.dark.onBrandPrimary, FollowThemeTokens.dark.brandPrimary),
  ]) {
    expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
  }
});

test('glass and layout tokens use the approved scale', () {
  expect(FollowThemeTokens.light.radiusCard, 16);
  expect(FollowThemeTokens.light.radiusPanel, 24);
  expect(FollowThemeTokens.light.glassStandard.blurSigma, inInclusiveRange(18, 24));
  expect(FollowThemeTokens.light.motionPalette, const Duration(milliseconds: 360));
});
```

Extend `app_theme_test.dart` to require the extension and exact text roles in
both themes.

```dart
expect(theme.extension<FollowThemeTokens>(), isNotNull);
expect(theme.textTheme.headlineLarge?.fontSize, 28);
expect(theme.textTheme.titleLarge?.fontSize, 20);
expect(theme.textTheme.bodyLarge?.fontSize, 16);
expect(theme.textTheme.labelMedium?.fontSize, 12);
```

**Step 2: Run the tests and verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/core/theme/follow_theme_tokens_test.dart test/core/theme/app_theme_test.dart
```

Expected: FAIL because `FollowThemeTokens` does not exist and `AppTheme` does
not expose the approved roles.

**Step 3: Implement the minimal token types**

Create immutable token values and a small `GlassSpec` value object. Store the
approved light/dark color roles, status colors, typography-related constants,
spacing, radii, icon sizes, glass tiers, and motion durations. Implement
`copyWith` and `lerp` so Flutter can animate theme changes.

```dart
@immutable
class GlassSpec {
  const GlassSpec({
    required this.blurSigma,
    required this.fill,
    required this.border,
  });

  final double blurSigma;
  final Color fill;
  final Color border;

  static GlassSpec lerp(GlassSpec a, GlassSpec b, double t) => GlassSpec(
    blurSigma: lerpDouble(a.blurSigma, b.blurSigma, t)!,
    fill: Color.lerp(a.fill, b.fill, t)!,
    border: Color.lerp(a.border, b.border, t)!,
  );
}

@immutable
class FollowThemeTokens extends ThemeExtension<FollowThemeTokens> {
  const FollowThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.brandPrimary,
    required this.onBrandPrimary,
    required this.brandSecondary,
    required this.auroraCyan,
    required this.glassLight,
    required this.glassStandard,
    required this.glassStrong,
  });

  static const light = FollowThemeTokens(/* approved light values */);
  static const dark = FollowThemeTokens(/* approved dark values */);

  // Fields, copyWith, and lerp.
}
```

Update `AppTheme.light` and `AppTheme.dark` to install the extension, define the
approved `TextTheme`, and theme native buttons, icon buttons, tabs, inputs,
cards, navigation, dividers, sliders, sheets, snackbars, and focus states from
semantic roles.

**Step 4: Run the focused tests**

Run the command from Step 2.

Expected: PASS.

**Step 5: Scoped checkpoint, if authorized**

```bash
git add follow/lib/core/theme/follow_theme_tokens.dart follow/lib/core/theme/app_theme.dart follow/test/core/theme/follow_theme_tokens_test.dart follow/test/core/theme/app_theme_test.dart
git commit -m "feat: define Follow aurora theme tokens"
```

### Task 2: Add shared aurora and grouped-glass primitives

**Files:**
- Create: `follow/lib/shared/widgets/surfaces/aurora_background.dart`
- Create: `follow/lib/shared/widgets/surfaces/glass_panel.dart`
- Create: `follow/lib/shared/widgets/section_header.dart`
- Create: `follow/test/shared/widgets/surfaces/aurora_background_test.dart`
- Create: `follow/test/shared/widgets/surfaces/glass_panel_test.dart`
- Create: `follow/test/shared/widgets/section_header_test.dart`

**Step 1: Write failing widget tests**

Prove that:

- brand aurora uses theme tokens and not `LoginColors`;
- reduced motion produces a static background;
- `GlassPanel` clips before applying `BackdropFilter.grouped`;
- all three glass tiers resolve from `FollowThemeTokens`;
- section headers use the theme text roles and do not hardcode font sizes.

```dart
await tester.pumpWidget(_themed(
  const BackdropGroup(
    child: GlassPanel(
      tier: GlassTier.standard,
      child: SizedBox(key: Key('content')),
    ),
  ),
));

expect(find.byType(ClipRRect), findsWidgets);
expect(find.byType(BackdropFilter), findsOneWidget);
expect(find.byKey(const Key('content')), findsOneWidget);
```

**Step 2: Verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/shared/widgets/surfaces test/shared/widgets/section_header_test.dart
```

Expected: FAIL because the widgets do not exist.

**Step 3: Implement the primitives**

`AuroraBackground` accepts a child and optional semantic accent overrides. Its
default mode uses only theme tokens and two static radial gradients. It does
not run a continuous animation.

`GlassPanel` selects `light`, `standard`, or `strong`, clips to the requested
shape, and uses grouped backdrop filtering.

```dart
enum GlassTier { light, standard, strong }

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.tier = GlassTier.standard,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(context, tier);
    final radius = borderRadius ?? BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(
          sigmaX: spec.blurSigma,
          sigmaY: spec.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: spec.fill,
            border: Border.all(color: spec.border),
            borderRadius: radius,
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}
```

**Step 4: Verify focused tests pass**

Run the Step 2 command.

Expected: PASS.

**Step 5: Scoped checkpoint, if authorized**

```bash
git add follow/lib/shared/widgets/surfaces follow/lib/shared/widgets/section_header.dart follow/test/shared/widgets/surfaces follow/test/shared/widgets/section_header_test.dart
git commit -m "feat: add aurora glass surface primitives"
```

### Task 3: Build the illustrated state system

**Files:**
- Create: `follow/lib/shared/widgets/states/app_state_kind.dart`
- Create: `follow/lib/shared/widgets/states/app_state_view.dart`
- Create: `follow/lib/shared/widgets/states/state_illustration_color_mapper.dart`
- Create: `follow/lib/shared/widgets/loading/app_content_skeleton.dart`
- Create: `follow/assets/illustrations/state_empty_library.svg`
- Create: `follow/assets/illustrations/state_empty_playlist.svg`
- Create: `follow/assets/illustrations/state_no_results.svg`
- Create: `follow/assets/illustrations/state_no_lyrics.svg`
- Create: `follow/assets/illustrations/state_empty_downloads.svg`
- Create: `follow/assets/illustrations/state_offline.svg`
- Create: `follow/assets/illustrations/state_failure.svg`
- Create: `follow/assets/illustrations/state_nothing_playing.svg`
- Modify: `follow/pubspec.yaml`
- Create: `follow/test/shared/widgets/states/app_state_view_test.dart`
- Create: `follow/test/shared/widgets/loading/app_content_skeleton_test.dart`

**Step 1: Write failing state tests**

Test every enum value so mappings cannot silently fall through. Require a
multi-color `SvgPicture`, a semantic illustration label, one optional primary
action, no button when no callback exists, mobile/desktop illustration sizing,
and large-text wrapping without overflow.

```dart
for (final kind in AppStateKind.values) {
  testWidgets('$kind renders an SVG illustration', (tester) async {
    await tester.pumpWidget(_themed(AppStateView(
      kind: kind,
      title: '状态标题',
      description: '可恢复的简短说明',
    )));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsNothing);
  });
}
```

Test the skeleton separately: it reserves final geometry, contains no state
illustration, and disables shimmer under reduced motion.

**Step 2: Verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/shared/widgets/states test/shared/widgets/loading
```

Expected: FAIL because the state system and assets do not exist.

**Step 3: Create deterministic SVG assets**

Author original vector assets with a shared `viewBox="0 0 240 240"`. Use these
sentinel colors so one immutable `ColorMapper` can map all illustrations:

- `#FF00FF`: illustration primary;
- `#00FFFF`: illustration secondary;
- `#808080`: muted fill;
- `#000000`: line and detail.

Use only vector paths, circles, ellipses, strokes, masks, and gradients. Do not
embed raster images, fonts, external links, emoji, or copied third-party art.
Keep the visual subjects exactly as approved in the design document.

**Step 4: Implement the state widget and mapper**

```dart
class StateIllustrationColorMapper extends ColorMapper {
  const StateIllustrationColorMapper(this.tokens);
  final FollowThemeTokens tokens;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => switch (color.toARGB32()) {
    0xFFFF00FF => tokens.brandPrimary,
    0xFF00FFFF => tokens.brandSecondary,
    0xFF808080 => tokens.surfaceElevated,
    0xFF000000 => tokens.textSecondary,
    _ => color,
  };
}
```

`AppStateView` maps `AppStateKind` to asset and illustration semantics but
accepts localized title, description, and action labels from the caller.
Register `assets/illustrations/` in `pubspec.yaml`.

**Step 5: Run tests and asset parsing checks**

Run:

```bash
cd follow
flutter test --no-pub test/shared/widgets/states test/shared/widgets/loading
flutter analyze --no-pub lib/shared/widgets/states lib/shared/widgets/loading
```

Expected: PASS with every asset decoded by `flutter_svg`.

**Step 6: Scoped checkpoint, if authorized**

```bash
git add follow/lib/shared/widgets/states follow/lib/shared/widgets/loading follow/assets/illustrations follow/pubspec.yaml follow/test/shared/widgets/states follow/test/shared/widgets/loading
git commit -m "feat: add illustrated application states"
```

### Task 4: Migrate home and library states first

**Files:**
- Modify: `follow/lib/features/home/views/favorites_view.dart`
- Modify: `follow/lib/features/home/views/playlist_view.dart`
- Modify: `follow/lib/features/home/views/recently_played_view.dart`
- Modify: `follow/lib/features/library/library_page.dart`
- Modify: `follow/lib/features/library/widgets/albums_tab.dart`
- Modify: `follow/lib/features/library/widgets/artists_tab.dart`
- Modify: `follow/lib/features/library/album_detail_page.dart`
- Modify: `follow/lib/features/library/artist_detail_page.dart`
- Create: `follow/test/features/home/home_state_views_test.dart`
- Create: `follow/test/features/library/library_state_views_test.dart`

**Step 1: Write failing page-state tests**

Override the existing providers with empty, error, and loading values. Require:

- the correct `AppStateKind` for each empty result;
- a retry action for failures;
- skeletons for initial loading;
- no raw `Icons.error_outline` or text-only empty state;
- existing list/play actions for non-empty data.

**Step 2: Verify regression tests fail**

Run:

```bash
cd follow
flutter test --no-pub test/features/home/home_state_views_test.dart test/features/library/library_state_views_test.dart
```

Expected: FAIL because pages still render legacy icon/text states and spinners.

**Step 3: Replace only state branches**

Use `AppStateView` and `AppContentSkeleton` while preserving provider reads,
pagination, refresh behavior, playback calls, ownership rules, and navigation.
Do not restyle populated cards in this task.

**Step 4: Verify focused and existing tests**

Run:

```bash
cd follow
flutter test --no-pub test/features/home test/features/library test/shared/widgets/empty_state_card_test.dart
```

Expected: PASS. The legacy empty-state test may remain until Task 6 deletes the
legacy widget.

**Step 5: Scoped checkpoint, if authorized**

```bash
git add follow/lib/features/home/views follow/lib/features/library follow/test/features/home/home_state_views_test.dart follow/test/features/library/library_state_views_test.dart
git commit -m "refactor: unify home and library state views"
```

### Task 5: Migrate search, downloads, settings, lyrics, queue, and player states

**Files:**
- Modify: `follow/lib/features/search/search_page.dart`
- Modify: `follow/lib/features/downloads/downloads_page.dart`
- Modify: `follow/lib/features/settings/session_management_sheet.dart`
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/lib/shared/widgets/lyrics/lyrics_failure_view.dart`
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`
- Modify: `follow/lib/shared/widgets/player/playlist_gallery_drawer.dart`
- Create: `follow/test/features/search/search_state_views_test.dart`
- Create: `follow/test/features/downloads/download_state_views_test.dart`
- Modify: `follow/test/features/settings/session_management_sheet_test.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Modify: `follow/test/shared/widgets/player/folded_track_queue_test.dart`
- Modify: `follow/test/shared/widgets/player/playlist_gallery_drawer_test.dart`

**Step 1: Write failing state contract tests**

Require distinct no-results, empty-downloads, offline, failure, no-lyrics,
empty-queue, playlist-failure, and nothing-playing variants. Prove retry and
navigation callbacks still invoke the existing behavior.

**Step 2: Verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/features/search test/features/downloads test/features/settings/session_management_sheet_test.dart test/features/player/interactive_lyrics_integration_test.dart test/shared/widgets/player/folded_track_queue_test.dart test/shared/widgets/player/playlist_gallery_drawer_test.dart
```

Expected: FAIL on legacy text/icon/spinner state output.

**Step 3: Replace state branches without changing data flow**

Keep network requests, search debounce, queue mutations, lyric seek behavior,
player back behavior, and playlist replacement behavior unchanged. The
`nothingPlaying` action navigates to the library. Failure actions invalidate
the same provider or invoke the same retry callback currently used.

**Step 4: Run focused tests**

Run the Step 2 command.

Expected: PASS.

**Step 5: Scoped checkpoint, if authorized**

```bash
git add follow/lib/features/search/search_page.dart follow/lib/features/downloads/downloads_page.dart follow/lib/features/settings/session_management_sheet.dart follow/lib/features/player/player_page.dart follow/lib/shared/widgets/lyrics/lyrics_failure_view.dart follow/lib/shared/widgets/player/folded_track_queue.dart follow/lib/shared/widgets/player/playlist_gallery_drawer.dart follow/test/features/search follow/test/features/downloads follow/test/features/settings/session_management_sheet_test.dart follow/test/features/player/interactive_lyrics_integration_test.dart follow/test/shared/widgets/player/folded_track_queue_test.dart follow/test/shared/widgets/player/playlist_gallery_drawer_test.dart
git commit -m "refactor: unify remaining application states"
```

### Task 6: Remove the legacy empty-state implementations

**Files:**
- Delete: `follow/lib/shared/widgets/empty_state.dart`
- Delete: `follow/lib/shared/widgets/empty_state_card.dart`
- Delete: `follow/test/shared/widgets/empty_state_card_test.dart`
- Create: `follow/test/core/theme/design_system_source_guard_test.dart`
- Modify: every remaining import reported by `rg "EmptyState(Card)?" follow/lib`

**Step 1: Write the failing source guard**

Scan `lib/` and fail if production code imports the legacy widgets, references
`LoginColors` outside the temporary allowlist, or adds new state branches that
use `Icons.error_outline` directly.

```dart
test('feature code does not depend on legacy visual constants', () {
  final violations = scanDartSources(
    forbidden: const ['LoginColors.', 'EmptyState(', 'EmptyStateCard('],
    allow: const ['lib/core/theme/app_theme.dart'],
  );
  expect(violations, isEmpty, reason: violations.join('\n'));
});
```

At this stage the `LoginColors` guard is allowed to fail outside state paths;
Task 12 removes the temporary allowlist and the class itself.

**Step 2: Run and verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/core/theme/design_system_source_guard_test.dart
```

Expected: FAIL with remaining legacy references.

**Step 3: Finish imports and delete legacy files**

Replace remaining state-only uses with `AppStateView`, then delete the two
legacy widgets and their obsolete test.

**Step 4: Verify no legacy state reference remains**

Run:

```bash
rg -n "EmptyState(Card)?" follow/lib
cd follow
flutter test --no-pub test/core/theme/design_system_source_guard_test.dart test/shared/widgets/states
```

Expected: `rg` returns no production matches; tests PASS.

**Step 5: Scoped checkpoint, if authorized**

```bash
git add follow/lib follow/test/core/theme/design_system_source_guard_test.dart follow/test/shared/widgets
git commit -m "refactor: retire legacy empty state widgets"
```

Before running that checkpoint command, replace the broad directory arguments
with the exact named files shown by `git diff --name-only`; do not stage
unrelated user changes.

### Task 7: Implement the cover-derived palette model and resolver

**Files:**
- Create: `follow/lib/core/theme/player_palette.dart`
- Create: `follow/lib/core/theme/player_palette_resolver.dart`
- Create: `follow/lib/core/theme/player_palette_provider.dart`
- Create: `follow/test/core/theme/player_palette_test.dart`
- Create: `follow/test/core/theme/player_palette_resolver_test.dart`
- Create: `follow/test/core/theme/player_palette_provider_test.dart`

**Step 1: Write failing pure model tests**

Prove:

- brand fallback values are deterministic in both themes;
- functional status colors are absent from `PlayerPalette`;
- primary-control/on-primary-control contrast is at least 4.5:1;
- progress against the player scrim is at least 3:1 or falls back;
- palette interpolation returns stable endpoints.

```dart
test('unsafe control accent falls back to the brand pair', () {
  final palette = PlayerPalette.guard(
    candidatePrimary: const Color(0xFFF7F6FC),
    candidateOnPrimary: Colors.white,
    candidateSecondary: const Color(0xFFF4F2FA),
    brightness: Brightness.light,
    tokens: FollowThemeTokens.light,
  );
  expect(palette.primaryControl, FollowThemeTokens.light.brandPrimary);
  expect(
    contrastRatio(palette.onPrimaryControl, palette.primaryControl),
    greaterThanOrEqualTo(4.5),
  );
});
```

**Step 2: Write failing resolver/cache tests**

Inject a fake `ImageProvider` extractor. Require one extraction for concurrent
requests with the same `(coverUri, brightness)`, distinct results for light and
dark, a bounded 64-entry cache, and fallback on missing cover or exceptions.

**Step 3: Verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/core/theme/player_palette_test.dart test/core/theme/player_palette_resolver_test.dart test/core/theme/player_palette_provider_test.dart
```

Expected: FAIL because the palette types do not exist.

**Step 4: Implement using Flutter's built-in content color API**

Use `CachedNetworkImageProvider` for the already-resolved same-origin cover URI
and `ColorScheme.fromImageProvider`. Flutter 3.44.8 downsamples content to at
most 112x112 for extraction, so no new palette dependency is needed.

```dart
final scheme = await ColorScheme.fromImageProvider(
  provider: imageProvider,
  brightness: brightness,
  dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  contrastLevel: 0.5,
);

return PlayerPalette.guard(
  candidatePrimary: scheme.primary,
  candidateOnPrimary: scheme.onPrimary,
  candidateSecondary: scheme.secondary,
  candidateAmbient: scheme.tertiary,
  brightness: brightness,
  tokens: tokens,
);
```

The guard rejects near-transparent values, candidate/on-candidate pairs below
the required ratio, and values that become indistinguishable from the scrim.
Ambient colors may be low contrast because they never carry content.

Expose a Riverpod family keyed by track id, normalized cover path, and
brightness. The provider delegates to a resolver service so tests can override
the extractor and cache.

**Step 5: Verify focused tests**

Run the Step 3 command.

Expected: PASS without network access.

**Step 6: Scoped checkpoint, if authorized**

```bash
git add follow/lib/core/theme/player_palette.dart follow/lib/core/theme/player_palette_resolver.dart follow/lib/core/theme/player_palette_provider.dart follow/test/core/theme/player_palette_test.dart follow/test/core/theme/player_palette_resolver_test.dart follow/test/core/theme/player_palette_provider_test.dart
git commit -m "feat: derive guarded player colors from cover art"
```

### Task 8: Build the dynamic player backdrop

**Files:**
- Create: `follow/lib/shared/widgets/player/player_aurora_background.dart`
- Create: `follow/test/shared/widgets/player/player_aurora_background_test.dart`
- Modify: `follow/lib/shared/widgets/track_cover_image.dart`
- Modify: `follow/test/shared/widgets/track_cover_image_test.dart`

**Step 1: Write failing background tests**

Require:

- the same normalized cover URI is used by the visible cover and atmosphere;
- one scaled blurred image layer exists;
- one theme scrim and two radial palette glows exist;
- cover identity changes crossfade over the token duration;
- missing/error artwork uses the brand fallback without a broken network
  widget;
- reduced motion removes spatial animation and keeps only a short fade or
  immediate replacement.

**Step 2: Verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/shared/widgets/player/player_aurora_background_test.dart test/shared/widgets/track_cover_image_test.dart
```

Expected: FAIL because the background does not exist and the cover provider is
not shared.

**Step 3: Extract a shared cover-provider helper**

Keep `resolveCoverUri` as the security boundary. Add a helper that returns a
`CachedNetworkImageProvider` only for a valid resolved URI. Reuse it in
`TrackCoverImage`, palette extraction, and the player background.

**Step 4: Implement the backdrop**

Use `AnimatedSwitcher` keyed by normalized cover identity, `ImageFiltered` for
the full cover blur, `RepaintBoundary` around the backdrop, a fixed theme scrim,
and two palette radial gradients. Do not use a continuously animated mesh.

```dart
Stack(
  fit: StackFit.expand,
  children: [
    RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
        child: Transform.scale(
          scale: 1.25,
          child: coverProvider == null
              ? const SizedBox.expand()
              : Image(image: coverProvider, fit: BoxFit.cover),
        ),
      ),
    ),
    DecoratedBox(decoration: BoxDecoration(gradient: themeScrim)),
    DecoratedBox(decoration: BoxDecoration(gradient: paletteGlow)),
    child,
  ],
);
```

**Step 5: Run focused tests**

Run the Step 2 command.

Expected: PASS.

**Step 6: Scoped checkpoint, if authorized**

```bash
git add follow/lib/shared/widgets/player/player_aurora_background.dart follow/lib/shared/widgets/track_cover_image.dart follow/test/shared/widgets/player/player_aurora_background_test.dart follow/test/shared/widgets/track_cover_image_test.dart
git commit -m "feat: add cover-adaptive player backdrop"
```

### Task 9: Integrate glass and dynamic palette into the mobile player

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Modify: `follow/lib/shared/widgets/player/player_main_controls.dart`
- Modify: `follow/lib/shared/widgets/player/player_volume_control.dart`
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`
- Modify: `follow/lib/shared/widgets/player/playlist_gallery_drawer.dart`
- Modify: `follow/lib/shared/widgets/play_queue_sheet.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Modify: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Modify: `follow/test/shared/widgets/player/player_main_controls_test.dart`
- Modify: `follow/test/shared/widgets/player/player_volume_control_test.dart`
- Modify: `follow/test/shared/widgets/player/folded_track_queue_test.dart`
- Modify: `follow/test/shared/widgets/player/playlist_gallery_drawer_test.dart`
- Modify: `follow/test/shared/widgets/play_queue_sheet_test.dart`

**Step 1: Add failing integration assertions before changing layout**

Extend tests to require:

- `PlayerAuroraBackground` receives the current track and resolved palette;
- a single `BackdropGroup` wraps non-overlapping glass surfaces;
- progress, primary control, vinyl glow, and queue selection use guarded
  player accents;
- title/body/error colors remain global semantic roles;
- the 280px record size and 104px track-information slot still exist on a
  normal phone;
- compact-height behavior remains non-overflowing;
- the existing keys for playlist pull, vinyl, lyrics, and queue remain;
- reduced motion keeps all actions available.

**Step 2: Run the player tests and verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/features/player/interactive_lyrics_integration_test.dart test/shared/widgets/player test/shared/widgets/play_queue_sheet_test.dart
```

Expected: FAIL on the new visual assertions while existing gesture tests still
pass.

**Step 3: Replace only the player visual composition**

Keep `_PlayerVisualMode`, gesture thresholds, provider reads, queue selection,
lyrics ownership, and playback methods intact. Replace the fixed gradient body
with `PlayerAuroraBackground`, install one `BackdropGroup`, and compose:

- light glass top chrome;
- unchanged flexible record/lyrics/queue region;
- unchanged reserved track-information slot;
- one standard glass control deck for progress, volume, and controls;
- strong glass for lyrics, queue, gallery, and sheets.

Do not turn every icon into a separate backdrop filter.

**Step 4: Apply dynamic accents narrowly**

Pass `PlayerPalette` only where needed. The primary playback control uses
`primaryControl/onPrimaryControl`; progress uses `progress`; the vinyl shadow
uses `glow`; queue selection and small player emphasis use `secondary`.
Everything else reads `FollowThemeTokens` or `ColorScheme`.

**Step 5: Run player tests**

Run the Step 2 command.

Expected: PASS, including existing gesture, rotation, queue, and lyric tests.

**Step 6: Scoped analyze**

Run:

```bash
cd follow
flutter analyze --no-pub lib/features/player lib/shared/widgets/player lib/shared/widgets/play_queue_sheet.dart
```

Expected: no issues.

**Step 7: Scoped checkpoint, if authorized**

```bash
git add follow/lib/features/player/player_page.dart follow/lib/shared/widgets/player follow/lib/shared/widgets/play_queue_sheet.dart follow/test/features/player/interactive_lyrics_integration_test.dart follow/test/shared/widgets/player follow/test/shared/widgets/play_queue_sheet_test.dart
git commit -m "feat: apply dynamic aurora glass player"
```

### Task 10: Align desktop player and lyrics without tinting the app shell

**Files:**
- Modify: `follow/lib/features/player/lyrics_overlay.dart`
- Modify: `follow/lib/shared/widgets/desktop_player_bar.dart`
- Modify: `follow/lib/router/app_router.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Create: `follow/test/shared/widgets/desktop_player_bar_theme_test.dart`
- Modify: `follow/test/router/mobile_navigation_spec_test.dart`

**Step 1: Write failing desktop-scope tests**

Require dynamic cover atmosphere inside the desktop player bar and lyrics
overlay only. Prove the main navigation rail and content scaffold retain the
global theme and the 800px navigation breakpoint remains unchanged.

**Step 2: Verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/features/player/interactive_lyrics_integration_test.dart test/shared/widgets/desktop_player_bar_theme_test.dart test/router/mobile_navigation_spec_test.dart
```

Expected: FAIL on the new scoped-theme assertions.

**Step 3: Implement scoped desktop atmosphere**

Reuse `PlayerPalette` and glass tiers, but do not wrap `_DesktopShell` in a
dynamic theme or cover background. Keep the shared `InteractiveLyricsView` and
its playback position/seek data flow unchanged.

**Step 4: Verify tests and analyze**

Run the Step 2 command, then:

```bash
cd follow
flutter analyze --no-pub lib/features/player/lyrics_overlay.dart lib/shared/widgets/desktop_player_bar.dart lib/router/app_router.dart
```

Expected: PASS and no issues.

**Step 5: Scoped checkpoint, if authorized**

```bash
git add follow/lib/features/player/lyrics_overlay.dart follow/lib/shared/widgets/desktop_player_bar.dart follow/lib/router/app_router.dart follow/test/features/player/interactive_lyrics_integration_test.dart follow/test/shared/widgets/desktop_player_bar_theme_test.dart follow/test/router/mobile_navigation_spec_test.dart
git commit -m "feat: align desktop playback with aurora theme"
```

### Task 11: Apply the global visual language to shell, login, and populated content

**Files:**
- Modify: `follow/lib/router/app_router.dart`
- Modify: `follow/lib/features/auth/login_page.dart`
- Modify: `follow/lib/features/home/home_page.dart`
- Modify: `follow/lib/features/library/library_page.dart`
- Modify: `follow/lib/features/library/widgets/albums_tab.dart`
- Modify: `follow/lib/features/library/widgets/artists_tab.dart`
- Modify: `follow/lib/features/library/widgets/library_search_box.dart`
- Modify: `follow/lib/features/search/search_page.dart`
- Modify: `follow/lib/features/search/widgets/sidebar_search_box.dart`
- Modify: `follow/lib/features/downloads/downloads_page.dart`
- Modify: `follow/lib/features/settings/settings_page.dart`
- Modify: `follow/lib/shared/widgets/app_logo.dart`
- Modify: `follow/lib/shared/widgets/mini_player.dart`
- Modify: `follow/lib/shared/widgets/smart_track_tile.dart`
- Modify: `follow/lib/shared/widgets/track_tile.dart`
- Modify: `follow/lib/shared/widgets/track_cover_image.dart`
- Modify: `follow/lib/shared/widgets/user_avatar.dart`
- Modify: relevant existing widget tests under `follow/test/features/` and `follow/test/shared/widgets/`
- Create: `follow/test/core/theme/populated_ui_source_guard_test.dart`

**Step 1: Write a failing migration guard**

The guard should forbid new raw visual constants in feature and shared-widget
code while allowing data-dependent geometry and the core theme implementation.
At minimum forbid `LoginColors`, raw `Color(0x...)`, and page-local title
`fontSize` declarations in the listed files.

Also add focused widget assertions for:

- navigation icon-plus-label selection and at least 48dp targets;
- login's one strong glass card;
- consistent H1/section headers;
- populated album/artist/track cards using card and type tokens;
- search and segmented controls using the standard glass/surface rules;
- destructive settings actions remaining visibly separate.

**Step 2: Run and verify failure**

Run:

```bash
cd follow
flutter test --no-pub test/core/theme/populated_ui_source_guard_test.dart test/features/auth test/features/home test/features/library test/features/search test/features/downloads test/features/settings test/router/mobile_navigation_spec_test.dart
```

Expected: FAIL with current hardcoded colors, sizes, and legacy component
styling.

**Step 3: Migrate one page family at a time**

Use `ThemeData`, `FollowThemeTokens`, `AuroraBackground`, `GlassPanel`, and
`SectionHeader`. Ordinary cards remain tonal and mostly opaque. Do not make all
application pages full-glass. Preserve providers, navigation, playback,
pagination, downloads, authentication, and settings behavior.

After each page family, run its existing tests before continuing.

**Step 4: Run focused tests and source guard**

Run the Step 2 command.

Expected: PASS.

**Step 5: Scoped checkpoint, if authorized**

Use `git diff --name-only` to construct a named-path `git add` command for only
the files migrated in this task, then:

```bash
git commit -m "refactor: apply Follow aurora language across app"
```

### Task 12: Remove `LoginColors` and finish the source-of-truth cleanup

**Files:**
- Modify: `follow/lib/core/theme/app_theme.dart`
- Modify: `follow/test/core/theme/design_system_source_guard_test.dart`
- Modify: `follow/test/core/theme/populated_ui_source_guard_test.dart`
- Modify: any production file still reported by the searches below

**Step 1: Tighten the failing guards**

Remove all temporary allowlists for `LoginColors`. Require zero production
references and require raw brand hex values to exist only in
`follow_theme_tokens.dart`.

**Step 2: Verify failure and enumerate exact remaining files**

Run:

```bash
rg -n "LoginColors|AppColorsDark?|Color\(0x" follow/lib -g '*.dart'
cd follow
flutter test --no-pub test/core/theme/design_system_source_guard_test.dart test/core/theme/populated_ui_source_guard_test.dart
```

Expected: FAIL until remaining legacy constants are removed.

**Step 3: Remove legacy color classes and final direct references**

Delete `LoginColors`, `AppColors`, and `AppColorsDark` after every caller uses
the semantic extension or `ColorScheme`. Keep only the approved token source
of truth.

**Step 4: Verify the cleanup**

Run the Step 2 commands again.

Expected: no forbidden production matches; both guards PASS.

**Step 5: Scoped checkpoint, if authorized**

```bash
git add follow/lib/core/theme/app_theme.dart follow/test/core/theme/design_system_source_guard_test.dart follow/test/core/theme/populated_ui_source_guard_test.dart
git commit -m "refactor: remove legacy visual constants"
```

Add any other final cleanup path explicitly to `git add`; never use a broad
repository add.

### Task 13: Add visual regression fixtures for both themes and extreme covers

**Files:**
- Create: `follow/test/helpers/visual_test_app.dart`
- Create: `follow/test/goldens/design_system_components_test.dart`
- Create: `follow/test/goldens/player_aurora_test.dart`
- Create: `follow/test/goldens/state_views_test.dart`
- Create: `follow/test/goldens/baselines/` PNG files after review

**Step 1: Write golden tests before accepting images**

Use fixed surface sizes, deterministic fake cover providers, fixed locale,
fixed text scale, disabled animations, and test-only images with known colors.
Cover at least:

- light and dark component boards;
- player with dark, bright, monochrome, neon, missing, and failed covers;
- all state illustrations in light and dark;
- 375x812 mobile, compact-height mobile, and 1280x800 desktop player surfaces.

```dart
await tester.binding.setSurfaceSize(const Size(375, 812));
await tester.pumpWidget(VisualTestApp(
  themeMode: ThemeMode.dark,
  disableAnimations: true,
  child: PlayerAuroraFixture(palette: darkCoverPalette),
));
await expectLater(
  find.byType(PlayerAuroraFixture),
  matchesGoldenFile('baselines/player_dark_cover.png'),
);
```

**Step 2: Verify tests fail without baselines**

Run:

```bash
cd follow
flutter test --no-pub test/goldens
```

Expected: FAIL because reviewed baseline images do not exist.

**Step 3: Generate candidate baselines**

Run:

```bash
cd follow
flutter test --no-pub --update-goldens test/goldens
```

Expected: candidate PNGs are created. This command is not acceptance.

**Step 4: Render and visually inspect every baseline**

Inspect every PNG at original scale. Check hierarchy, clipping, Chinese text,
glass edge consistency, contrast, state illustration integrity, compact-height
fit, and extreme-cover fallback. Correct source and regenerate until the set is
approved.

**Step 5: Run golden tests normally**

Run the Step 2 command.

Expected: PASS.

**Step 6: Scoped checkpoint, if authorized**

```bash
git add follow/test/helpers/visual_test_app.dart follow/test/goldens
git commit -m "test: add aurora visual regression baselines"
```

### Task 14: Full verification and release-boundary handoff

**Files:**
- Modify only files required by failures found in this task
- Review: `docs/plans/2026-09-01-follow-aurora-design-language-design.md`
- Review: `docs/plans/2026-09-01-follow-aurora-design-language.md`

**Step 1: Format only changed Dart files**

Build the file list from the scoped diff and run `dart format` only on those
Dart paths. Do not format unrelated dirty files.

**Step 2: Run source and whitespace checks**

Run:

```bash
git diff --check
rg -n "LoginColors|EmptyState(Card)?" follow/lib -g '*.dart'
```

Expected: no whitespace errors and no legacy production references.

**Step 3: Run focused design-system and player suites**

Run:

```bash
cd follow
flutter test --no-pub test/core/theme test/shared/widgets/states test/shared/widgets/surfaces test/shared/widgets/player test/features/player test/goldens
```

Expected: PASS.

**Step 4: Run full Flutter verification**

Run:

```bash
cd follow
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Expected: analyze reports no issues, all tests pass, and the debug APK exists
at `follow/build/app/outputs/flutter-apk/app-debug.apk`.

**Step 5: Profile the real player separately**

On an Android emulator and at least one real Android device, inspect the
performance overlay or DevTools while:

- changing tracks rapidly across extreme covers;
- opening/closing playlist gallery;
- revealing and scrolling the folded queue;
- entering and browsing lyrics;
- switching light/dark themes;
- enabling reduced motion and large text.

Acceptance target: no recurring build/raster frame overruns during steady
playback, no palette extraction per frame, and no gesture regression. If blur
cost is excessive, reduce sigma/tier count before reducing contrast.

**Step 6: Report proof in separate categories**

Report:

1. implemented files and migrated pages;
2. focused tests;
3. full analyze/test/build;
4. reviewed goldens/screenshots;
5. emulator performance;
6. real-device performance, gestures, large text, and screen reader status.

Do not describe local tests or an APK build as real-device visual acceptance.

**Step 7: Final scoped checkpoint, if authorized**

Review `git diff --stat`, `git diff --check`, and the exact named path list.
Commit only remaining task paths with an explicit user-approved message. Do
not push, merge, deploy, or create a release unless separately requested.

## Recommended Execution Order

Tasks 1-3 establish the design system. Tasks 4-6 migrate states before broader
visual work. Tasks 7-10 implement the player-specific dynamic system while
protecting existing gesture tests. Tasks 11-12 complete the destructive global
migration and remove legacy visual sources. Tasks 13-14 provide visual,
functional, build, and device evidence.

Do not parallelize tasks that edit `player_page.dart`, `app_theme.dart`, or the
same widget tests. SVG asset authoring may run independently only after the
sentinel-color contract in Task 3 is fixed.
