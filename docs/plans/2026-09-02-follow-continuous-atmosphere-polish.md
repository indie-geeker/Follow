# Follow Continuous Atmosphere Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make home and player surfaces visually continuous across system chrome, transient player layers, queue, and lyrics.

**Architecture:** Keep one atmospheric background owner per page and make child layers transparent or palette-tinted overlays. Preserve all existing navigation, scroll, and gesture state machines; only change layout insets and visual compositing.

**Tech Stack:** Flutter, Riverpod, widget tests, golden tests

---

### Task 1: Extend the home atmosphere through the status bar

**Files:**
- Modify: `follow/lib/features/home/home_page.dart`
- Modify: `follow/lib/features/home/widgets/home_aurora_header.dart`
- Modify: `follow/test/features/home/home_collapsing_header_test.dart`
- Modify: `follow/test/features/home/home_aurora_header_test.dart`
- Modify: `follow/test/router/mobile_navigation_spec_test.dart`

**Step 1: Write the failing tests**

Assert that the shared background reaches y=0, header controls start below the
top system inset, collapsed tabs pin below that inset, and the hero's final
gradient stop is transparent.

**Step 2: Run test to verify RED**

Run:
`flutter test --no-pub test/features/home/home_collapsing_header_test.dart test/features/home/home_aurora_header_test.dart test/router/mobile_navigation_spec_test.dart`

Expected: FAIL because `HomeScrollSafeArea` currently pushes the whole nested
scroll view below the status bar and the hero paints an independent full
rectangle.

**Step 3: Implement the minimal change**

Move top safe-area responsibility into `HomeCollapsingHeader`, include
`MediaQuery.padding.top` in its extents, annotate status-bar icon brightness,
and make the hero gradient dissolve to transparent at its bottom edge.

**Step 4: Verify GREEN**

Run the Task 1 command. Expected: PASS.

### Task 2: Make player title chrome follow the active atmosphere

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Write the failing tests**

Assert that resting player chrome uses a palette tint instead of the neutral
surface, playlist pull changes the tint continuously, and a fully open gallery
does not leave an opaque neutral stripe between gallery and player.

**Step 2: Run test to verify RED**

Run:
`flutter test --no-pub test/features/player/interactive_lyrics_integration_test.dart`

Expected: FAIL because the current top chrome combines a palette-colored box
with a neutral `GlassPanel` fill.

**Step 3: Implement the minimal change**

Replace the nested neutral panel with one palette-tinted backdrop blur/scrim.
Interpolate its opacity from the existing resting value through playlist reveal
progress. Do not change the pull threshold or gesture surfaces.

**Step 4: Verify GREEN**

Run the Task 2 command. Expected: PASS.

### Task 3: Retint the folded queue surface

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`
- Modify: `follow/test/shared/widgets/player/folded_track_queue_test.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Write the failing tests**

Assert that the folded queue's outer surface uses the supplied player palette,
has a low-alpha fill and subtle border, and contains no strong neutral
`GlassPanel`.

**Step 2: Run test to verify RED**

Run:
`flutter test --no-pub test/shared/widgets/player/folded_track_queue_test.dart test/features/player/interactive_lyrics_integration_test.dart`

Expected: FAIL because `player_page.dart` currently wraps the queue in
`GlassTier.strong`.

**Step 3: Implement the minimal change**

Let `FoldedTrackQueue` own a palette-tinted blurred surface and remove the
outer strong neutral panel. Preserve dimensions, scrolling, semantics, and
auto-close behavior.

**Step 4: Verify GREEN**

Run the Task 3 command. Expected: PASS.

### Task 4: Remove the mobile lyrics card

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Modify: `follow/test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

**Step 1: Write the failing tests**

Assert that the mobile lyrics surface directly contains
`InteractiveLyricsView`, has no descendant `GlassPanel`, and retains its
gesture surface, semantics, and horizontal content gutter.

**Step 2: Run test to verify RED**

Run:
`flutter test --no-pub test/features/player/interactive_lyrics_integration_test.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: FAIL because `_buildLyricsSurface` wraps lyrics in a strong glass
panel with card margins.

**Step 3: Implement the minimal change**

Remove only the mobile lyrics `Padding + GlassPanel` wrapper. Keep the
existing `GestureDetector`, page sizing, and internal lyric layout.

**Step 4: Verify GREEN**

Run the Task 4 command. Expected: PASS.

### Task 5: Visual and full verification

**Files:**
- Modify only when visually reviewed:
  `follow/test/goldens/baselines/*.png`

**Step 1: Format scoped Dart files**

Run `dart format` only on paths changed by Tasks 1-4.

**Step 2: Run focused and golden tests**

Run:
`flutter test --no-pub test/features/home test/features/player test/shared/widgets/player test/shared/widgets/lyrics test/goldens`

Expected: functional tests pass; intended golden changes are reviewed at
original size before accepting baselines.

**Step 3: Run full verification**

Run:
`flutter analyze --no-pub`
`flutter test --no-pub`
`flutter build apk --debug --no-pub`
`git diff --check`

Expected: no analyzer issues, all tests pass, APK exists, and no whitespace
errors.

**Step 4: Emulator acceptance**

Install the APK on the connected emulator. Verify the unauthenticated route,
then leave authenticated home/player checks explicit if no credentials are
available. Do not infer real-device performance from emulator results.
