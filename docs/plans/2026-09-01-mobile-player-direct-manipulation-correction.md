# Mobile Player Direct-Manipulation Correction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace modal-like player transitions with approved axis-locked, layered, direct-manipulation gestures while preserving ViewPager-like record/lyrics paging.

**Architecture:** Extend `PlayerCoverArt` into an axis-locked gesture surface that reports continuous visual displacement. Keep the playlist page behind a translated full player `Scaffold`, and keep a transparent cover-only queue behind the main record. `PlayerPage` owns settle states and pager/reveal progress; leaf widgets remain presentation-focused.

**Tech Stack:** Flutter 3.41, Dart, Riverpod, Material 3, flutter_test.

**Working-tree note:** The approved feature depends on existing uncommitted player and lyrics work on `main`. Modify only the named Flutter files/tests and these plan documents. Do not reset, clean, stage, commit, push, deploy, or touch server files.

---

### Task 1: Lock record movement to one cardinal axis

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Test: `follow/test/shared/widgets/player/player_cover_art_test.dart`

**Steps:**
1. Add a failing drag-in-progress test proving a diagonal drag produces either `dx == 0` or `dy == 0` after the 10dp lock threshold.
2. Add a failing test for continuous visual-offset reporting and an optional resting offset.
3. Run the focused test and verify the failures describe the missing behavior.
4. Add dominant-axis lock state, project cumulative drag onto that axis, expose `restingOffset` and `onVisualOffsetChanged`, and preserve the existing completion callbacks.
5. Run the focused test and expect all cases to pass.

### Task 2: Replace the queue panel with a cover-only underlay

**Files:**
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`
- Test: `follow/test/shared/widgets/player/folded_track_queue_test.dart`

**Steps:**
1. Replace panel-oriented expectations with failing tests for a transparent layer, no title/close/text rows, circular covers, orbit offsets, reveal opacity, scrolling, and selection.
2. Run the focused test and verify RED.
3. Implement a transparent vertical cover list driven by `revealProgress`.
4. Keep semantics and a minimum 48dp tappable cover target.
5. Run the focused test and expect GREEN.

### Task 3: Integrate queue reveal and ViewPager-like lyrics paging

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Steps:**
1. Add failing tests that pause mid-right-drag and assert the main record moved while the queue is partially visible below it.
2. Add failing tests that pause mid-left-drag and assert record and lyrics occupy adjacent ViewPager positions.
3. Run the integration test and verify RED.
4. Replace the queue visual mode with queue-open state and continuous reveal progress; always paint queue below the record.
5. Replace the record-to-lyrics switch with a horizontal pager progress shared by record and lyrics transforms.
6. Preserve lyric vertical scrolling, queue selection, buttons, track gestures, reduced motion, and system back.
7. Run focused player, queue, cover, lyrics, and controls tests.

### Task 4: Replace the playlist popup with a page that pushes the player

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/lib/shared/widgets/player/playlist_gallery_drawer.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Test: `follow/test/shared/widgets/player/playlist_gallery_drawer_test.dart`

**Steps:**
1. Add failing tests proving the gallery exists behind the player, has no modal scrim/rounded popup, and the full player surface follows partial vertical drag.
2. Add a failing settle test proving the player is displaced by the gallery height when open and returns after playlist selection.
3. Run both test files and verify RED.
4. Render the gallery as a full-width page without popup decoration.
5. Put the full player `Scaffold` above it in a root `Stack` and translate the player by live reveal offset.
6. Support downward open, upward close, selection close, retry, and system back.
7. Run both test files and expect GREEN.

### Task 5: Full verification and scope review

**Files:**
- Format only correction-related Dart files and tests.

**Steps:**
1. Run scoped `dart format`.
2. Run `fvm flutter analyze --no-pub` and expect no findings.
3. Run `fvm flutter test --no-pub` and expect all tests to pass.
4. Run `fvm flutter build apk --debug --no-pub` and capture the APK path.
5. Remove only build-tool-induced `gradle.properties` or lock-file changes if present.
6. Run `git diff --check`, review named diffs, and report device validation separately.
