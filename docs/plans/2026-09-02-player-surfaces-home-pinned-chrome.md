# Player Surfaces and Home Pinned Chrome Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the folded queue's panel silhouette, give playlist text a deterministic readable surface, and make pinned home tabs and the status-bar inset one opaque surface.

**Architecture:** Keep interaction state and gesture ownership unchanged. Repair the rendering boundaries at their source: make `FoldedTrackQueue` visually transparent, make `PlaylistGalleryDrawer` own an opaque semantic reading surface, and let `HomeCollapsingHeader` paint a collapse-progress-driven surface across its full safe-area-aware extent.

**Tech Stack:** Flutter 3.44.8 through FVM, Material 3, Riverpod, Flutter widget tests.

---

### Task 1: Establish a clean Flutter test baseline

**Files:**
- Inspect: `follow/pubspec.yaml`
- Inspect: `follow/pubspec.lock`

**Step 1: Resolve cached dependencies without upgrading**

Run: `cd follow && fvm flutter pub get --offline`

Expected: dependency resolution succeeds. If `pubspec.lock` changes only because of the local SDK cache, restore that file after generated sources are available.

**Step 2: Generate ignored source files when absent**

Run: `cd follow && fvm dart run build_runner build --delete-conflicting-outputs`

Expected: Riverpod, Freezed, JSON, and AutoRoute generated sources are available.

**Step 3: Run the existing focused baseline**

Run: `cd follow && fvm flutter test --no-pub test/shared/widgets/player/folded_track_queue_test.dart test/shared/widgets/player/playlist_gallery_drawer_test.dart test/features/home/home_collapsing_header_test.dart`

Expected: existing tests pass before regression expectations are changed.

### Task 2: Remove the folded queue's visual container

**Files:**
- Modify: `follow/test/shared/widgets/player/folded_track_queue_test.dart`
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`

**Step 1: Write the failing test**

Replace the prior gradient-surface assertion with assertions that the keyed queue visual root is transparent and that no `BackdropFilter` or decorated palette background wraps the queue content. Retain assertions for circular cover accents and interaction behavior.

**Step 2: Run the test to verify RED**

Run: `cd follow && fvm flutter test --no-pub test/shared/widgets/player/folded_track_queue_test.dart`

Expected: FAIL because `foldedQueuePaletteSurfaceKey` still identifies a gradient `DecoratedBox` under a rounded blur.

**Step 3: Implement the minimal rendering change**

Remove the outer `ClipRRect`, `BackdropFilter`, and gradient `DecoratedBox`. Keep the existing key on a transparent structural widget so tests can verify the rendering boundary without changing layout, reveal animation, scrolling, or hit testing.

**Step 4: Run the focused test to verify GREEN**

Run: `cd follow && fvm flutter test --no-pub test/shared/widgets/player/folded_track_queue_test.dart`

Expected: all folded-queue tests pass.

### Task 3: Give the playlist gallery a deterministic readable surface

**Files:**
- Modify: `follow/test/shared/widgets/player/playlist_gallery_drawer_test.dart`
- Modify: `follow/lib/shared/widgets/player/playlist_gallery_drawer.dart`

**Step 1: Write failing light/dark surface tests**

Pump the empty gallery with the app's light and dark themes. Assert that the gallery root uses the theme's semantic `surface` at alpha 1, that it no longer uses `GlassPanel`, and that the title/body styles resolve to `textPrimary`/`textSecondary`.

**Step 2: Run the tests to verify RED**

Run: `cd follow && fvm flutter test --no-pub test/shared/widgets/player/playlist_gallery_drawer_test.dart`

Expected: FAIL because the gallery currently uses `GlassTier.strong` plus a cover-palette gradient.

**Step 3: Implement the opaque gallery surface**

Replace the glass wrapper and full-surface gradient with an opaque `ColoredBox` using `context.followTokens.surface`. Keep the existing safe area, layout, state illustration, paging, gestures, and playlist record accents. Give the empty/error state explicit semantic foreground roles without changing the shared `AppStateView` globally.

**Step 4: Run the gallery tests to verify GREEN**

Run: `cd follow && fvm flutter test --no-pub test/shared/widgets/player/playlist_gallery_drawer_test.dart`

Expected: all gallery tests pass in both themes.

### Task 4: Unify pinned tabs and the system inset

**Files:**
- Modify: `follow/test/features/home/home_collapsing_header_test.dart`
- Modify: `follow/lib/features/home/home_page.dart`

**Step 1: Write failing collapse-state tests**

Assert that the fully collapsed tab surface is alpha 1, a keyed full-height pinned surface covers the status inset with the same color, the expanded state remains transparent, and the status-bar icon brightness matches light/dark themes.

**Step 2: Run the tests to verify RED**

Run: `cd follow && fvm flutter test --no-pub test/features/home/home_collapsing_header_test.dart test/features/home/home_scroll_safe_area_test.dart`

Expected: FAIL because the tab surface tops out at 0.82 opacity and the system inset has no matching opaque layer.

**Step 3: Implement the safe-area-aware pinned surface**

Use the existing collapse progress to fade a semantic surface across the complete sliver extent. At progress 1 it must cover the top inset and tab row with alpha 1. Preserve the expanded aurora, pinned geometry, snap behavior, and theme-correct overlay icon brightness.

**Step 4: Run the home tests to verify GREEN**

Run: `cd follow && fvm flutter test --no-pub test/features/home/home_collapsing_header_test.dart test/features/home/home_scroll_safe_area_test.dart test/features/home/home_aurora_header_test.dart`

Expected: all home header tests pass.

### Task 5: Regression and visual verification

**Files:**
- Verify: all modified Dart files and tests

**Step 1: Format and inspect the scoped diff**

Run: `cd follow && fvm dart format lib/shared/widgets/player/folded_track_queue.dart lib/shared/widgets/player/playlist_gallery_drawer.dart lib/features/home/home_page.dart test/shared/widgets/player/folded_track_queue_test.dart test/shared/widgets/player/playlist_gallery_drawer_test.dart test/features/home/home_collapsing_header_test.dart`

Expected: formatting completes and `git diff --check` reports no whitespace errors.

**Step 2: Run scoped analysis and focused tests**

Run: `cd follow && fvm flutter analyze --no-pub`

Run: `cd follow && fvm flutter test --no-pub test/shared/widgets/player/folded_track_queue_test.dart test/shared/widgets/player/playlist_gallery_drawer_test.dart test/features/home/home_collapsing_header_test.dart test/features/player/interactive_lyrics_integration_test.dart`

Expected: no analyzer issues and all focused tests pass.

**Step 3: Run the complete Flutter suite**

Run: `cd follow && fvm flutter test --no-pub`

Expected: all tests pass, including unchanged goldens.

**Step 4: Build and inspect on Android**

Run: `cd follow && fvm flutter build apk --debug --no-pub`

Run the app on the available Android emulator and verify the three supplied scenarios: no rectangular queue surface, readable empty gallery copy, and one opaque pinned home/status surface.

**Step 5: Final scope audit**

Run: `git status --short`, `git diff --check`, and `git diff --stat`.

Expected: only the approved implementation, tests, and these two planning documents are modified. Leave the branch uncommitted unless the user explicitly requests a commit.
