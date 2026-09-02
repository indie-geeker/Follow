# Follow Home and Player Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver the approved snapping cover-inspired home header and repair the five reported player visual, latency, and spacing defects without changing established gesture semantics.

**Architecture:** Keep the existing Riverpod providers, nested home tabs, and player gesture ownership. Introduce one reusable home-header visual component, replace the home header slivers with a snapping pinned `SliverAppBar`, make track selection optimistic before asynchronous source preparation, and fix player compositing at explicit layer boundaries.

**Tech Stack:** Flutter, Dart, Riverpod, AutoRoute, `flutter_test`, existing Follow theme/palette primitives.

---

### Task 1: Build the cover-inspired home hero artwork

**Files:**
- Create: `follow/lib/features/home/widgets/home_aurora_header.dart`
- Create: `follow/test/features/home/home_aurora_header_test.dart`
- Modify: `follow/lib/features/home/home_page.dart`

**Step 1: Write the failing tests**

Cover these observable behaviors:

```dart
testWidgets('first launch renders the brand record aurora without an image', ...);
testWidgets('recent artwork palette preserves the same header geometry', ...);
testWidgets('collapse progress fades decorative artwork but keeps greeting semantics', ...);
```

Use keys for the hero, brand fallback, groove motif, waveform motif, and greeting.
Assert decorative painters are excluded from semantics and that the component
height is identical with and without a recent track.

**Step 2: Run the tests and verify RED**

```bash
cd follow
flutter test --no-pub test/features/home/home_aurora_header_test.dart
```

Expected: FAIL because `HomeAuroraHeader` and its keys do not exist.

**Step 3: Implement the minimal header**

Create a `HomeAuroraHeader` accepting `Track? accentTrack`,
`PlayerPalette palette`, `double collapseProgress`, user name, logo/avatar
slots, and fixed expanded height. Paint brand/recent palette glows, cropped
record grooves, and a restrained waveform with Flutter vector primitives.
Do not add raster assets. Use the brand fallback whenever the track or cover
palette is unavailable.

**Step 4: Verify GREEN**

Run the Task 1 test command. Expected: PASS.

**Step 5: Scoped checkpoint, if authorized**

Stage only the three Task 1 paths. Do not commit without explicit user
authorization.

### Task 2: Replace the home header with a snapping pinned tab sliver

**Files:**
- Modify: `follow/lib/features/home/home_page.dart`
- Create: `follow/test/features/home/home_collapsing_header_test.dart`
- Modify: `follow/test/router/mobile_navigation_spec_test.dart`

**Step 1: Write the failing tests**

Build a deterministic home-header harness with a tall inner list and verify:

```dart
testWidgets('tabs pin below the status bar after the hero fully collapses', ...);
testWidgets('a short collapse drag snaps the hero open', ...);
testWidgets('a drag beyond the snap midpoint completes collapse', ...);
testWidgets('collapsed tabs add glass separation without an opaque color seam', ...);
```

Keep the existing safe-area assertion. Assert the greeting is off-screen after
collapse while the tab strip stays at the safe-area top.

**Step 2: Run and verify RED**

```bash
cd follow
flutter test --no-pub test/features/home/home_collapsing_header_test.dart test/router/mobile_navigation_spec_test.dart
```

Expected: FAIL against the current two `SliverToBoxAdapter` headers and fixed
opaque `_StickyTabBarDelegate`.

**Step 3: Implement the snapping header**

Use a pinned, floating, snapping `SliverAppBar` with `toolbarHeight: 0`, a 48dp
tab bottom, and the approved flexible hero. Derive collapse progress from the
sliver constraints. Keep one `AuroraBackground`; blend the tab fill from
transparent to the theme glass surface only near the collapsed endpoint.
Preserve dynamic user-playlist tabs and the add-playlist action.

**Step 4: Verify GREEN**

Run the Task 2 test command. Expected: PASS.

**Step 5: Scoped checkpoint, if authorized**

Stage only Task 2 paths. Do not commit without authorization.

### Task 3: Open the mobile player before asynchronous audio preparation

**Files:**
- Modify: `follow/lib/data/providers/audio_provider.dart`
- Modify: `follow/lib/router/player_navigation.dart`
- Modify: `follow/test/data/providers/audio_playback_start_test.dart`
- Create: `follow/test/router/player_navigation_test.dart`

**Step 1: Write the failing tests**

Add a coordinator-level test with a pending playback completer and a navigation
callback:

```dart
test('mobile navigation starts before the playback future completes', () async {
  final playback = Completer<void>();
  final events = <String>[];
  await startTrackSelection(
    play: () { events.add('play'); return playback.future; },
    openPlayer: () async => events.add('open');
  );
  expect(events, ['play', 'open']);
  expect(playback.isCompleted, isFalse);
});
```

Also verify desktop waits for playback, and verify the selected track state is
published before token/source preparation is awaited.

**Step 2: Run and verify RED**

```bash
cd follow
flutter test --no-pub test/router/player_navigation_test.dart test/data/providers/audio_playback_start_test.dart
```

Expected: FAIL because mobile currently awaits `play()` before pushing.

**Step 3: Implement the minimal ordering change**

Extract a small injectable coordinator used by `playTrackAndOpenPlayer`.
Invoke playback, open the compact player immediately, and attach safe deferred
error handling rather than awaiting source readiness. Publish `currentTrack`
before the first asynchronous token/source wait; keep the existing failure
provider responsible for rollback and feedback. Preserve desktop wait-only
behavior.

**Step 4: Verify GREEN**

Run the Task 3 test command. Expected: PASS with no unhandled asynchronous
errors.

**Step 5: Scoped checkpoint, if authorized**

Stage only Task 3 paths. Do not commit without authorization.

### Task 4: Isolate the playlist drawer and coordinate pull opacity

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Write the failing tests**

Add tests for:

```dart
testWidgets('closed playlist drawer is invisible and excluded from semantics', ...);
testWidgets('pull progress fades the drawer in and reduces top chrome opacity', ...);
testWidgets('sub-threshold pull returns drawer opacity and translation to zero', ...);
testWidgets('resting title bar paints a non-transparent cover-compatible surface', ...);
```

Assert actual `Opacity`, `IgnorePointer`, `ExcludeSemantics`, and top-chrome
decoration values. Retain the existing 88dp open-threshold behavior.

**Step 2: Run and verify RED**

```bash
cd follow
flutter test --no-pub test/features/player/interactive_lyrics_integration_test.dart
```

Expected: FAIL because the mounted drawer currently paints at full opacity
behind a transparent title bar.

**Step 3: Implement the minimal layer fix**

Wrap the gallery in opacity controlled by normalized pull progress. Keep it
ignored and excluded when fully closed. Replace transparent AppBar chrome with
a palette-compatible glass/scrim whose alpha interpolates from 0.82 at rest to
0.30 while pulling. Fade the handle guidance from hidden to visible and change
copy at the release threshold. Do not move gesture ownership outside the
existing pull handle.

**Step 4: Verify GREEN**

Run the Task 4 test command. Expected: PASS, including all pre-existing queue,
lyrics, and pull-cancellation tests.

**Step 5: Scoped checkpoint, if authorized**

Stage only Task 4 paths. Do not commit without authorization.

### Task 5: Make backdrop cover transitions viewport-stable

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_aurora_background.dart`
- Modify: `follow/test/shared/widgets/player/player_aurora_background_test.dart`

**Step 1: Write the failing tests**

Pump two test images with different intrinsic aspect ratios and switch tracks
mid-frame. Assert both outgoing and incoming keyed layers equal the full
viewport rectangle throughout the transition. Assert the switcher layout stack
uses expanding constraints and no uncovered horizontal band exists.

**Step 2: Run and verify RED**

```bash
cd follow
flutter test --no-pub test/shared/widgets/player/player_aurora_background_test.dart
```

Expected: FAIL because the current default `AnimatedSwitcher` layout can size
loose children from their intrinsic image geometry.

**Step 3: Implement the minimal compositor fix**

Provide an expanding switcher `layoutBuilder`, wrap each keyed background in
`SizedBox.expand`, and keep blur/scale inside that fixed viewport. Keep scrim
and glows outside the switcher. Preserve palette timing and the reduced-motion
zero-duration path.

**Step 4: Verify GREEN**

Run the Task 5 test command. Expected: PASS.

**Step 5: Scoped checkpoint, if authorized**

Stage only Task 5 paths. Do not commit without authorization.

### Task 6: Re-space playback controls and narrow the mode popup

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_main_controls.dart`
- Modify: `follow/lib/shared/widgets/player/player_mode_control.dart`
- Modify: `follow/test/shared/widgets/player/player_main_controls_test.dart`
- Modify: `follow/test/shared/widgets/player/player_mode_control_test.dart`

**Step 1: Write the failing tests**

At 360dp and 390dp widths, assert five equal center slots, at least 10dp visual
separation between secondary button surfaces, a centered 56dp primary control,
and minimum 48dp tap targets. Assert popup width is 112dp, labels remain one
line, and viewport correction still keeps the popup at least 8dp from edges.

**Step 2: Run and verify RED**

```bash
cd follow
flutter test --no-pub test/shared/widgets/player/player_main_controls_test.dart test/shared/widgets/player/player_mode_control_test.dart
```

Expected: FAIL because current controls use 4dp spacer pairs and popup width is
128dp.

**Step 3: Implement the minimal layout change**

Use five `Expanded` equal slots with centered children inside 12–16dp row
padding. Preserve the primary button size and every tooltip/semantic label.
Set popup width to 112dp and tune item horizontal padding only as needed to
avoid wrapping.

**Step 4: Verify GREEN**

Run the Task 6 test command. Expected: PASS.

**Step 5: Scoped checkpoint, if authorized**

Stage only Task 6 paths. Do not commit without authorization.

### Task 7: Visual regression and full verification

**Files:**
- Modify only if reviewed output exposes a defect:
  `follow/test/goldens/baselines/components_light.png`
  `follow/test/goldens/baselines/components_dark.png`
  `follow/test/goldens/baselines/player_dark_cover.png`
  `follow/test/goldens/baselines/player_bright_cover.png`
  `follow/test/goldens/baselines/player_compact_height.png`

**Step 1: Format only changed Dart paths**

Build the list from the scoped diff and run `dart format` only on those paths.

**Step 2: Run focused verification**

```bash
cd follow
flutter test --no-pub test/features/home test/router/player_navigation_test.dart test/data/providers/audio_playback_start_test.dart test/features/player test/shared/widgets/player test/goldens
```

Expected: PASS.

**Step 3: Review candidate goldens**

Generate candidates only if expected visual baselines changed, inspect every
changed PNG at original scale, then run goldens normally. Candidate generation
is not acceptance.

**Step 4: Run full verification**

```bash
cd follow
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Expected: no analyzer issues, all tests pass, and the debug APK exists.

**Step 5: Emulator acceptance**

Check light/dark home continuity, short/long header drag snap, immediate player
entry, repeated rapid track changes, slow playlist pull, controls at compact
width, large text, reduced motion, and TalkBack labels. Record profile/real
device performance separately and do not infer it from debug emulator results.

**Step 6: Final scoped checkpoint, if authorized**

Review the exact changed/untracked list and whitespace. Do not stage broadly,
commit, push, merge, or deploy without explicit authorization.
