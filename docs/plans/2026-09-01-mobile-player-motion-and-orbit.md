# Mobile Player Motion and Orbit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a polished dismissible playlist gallery, a center-snapping orbit queue, slow playback-driven vinyl rotation, and safe vertical gesture bounds.

**Architecture:** `PlayerPage` continues to own the player-layer state and supplies playback state and geometry to presentation widgets. `PlaylistGalleryDrawer` owns one horizontal page controller and exposes a full-surface dismissal callback. `FoldedTrackQueue` becomes a stateful fixed-extent viewport that derives arc transforms from scroll position and requests playback only after settling.

**Tech Stack:** Flutter 3.41.6, Dart, Riverpod, Material 3, flutter_test.

**Working-tree note:** Work in the current dirty `main` checkout because the feature builds on the existing uncommitted player implementation. Modify only the named Flutter files, tests, and these plan documents. Do not reset, clean, stage, commit, push, deploy, or touch server files.

---

### Task 1: Beautify and dismiss the playlist gallery

**Files:**
- Modify: `follow/lib/shared/widgets/player/playlist_gallery_drawer.dart`
- Modify: `follow/lib/features/player/player_page.dart`
- Test: `follow/test/shared/widgets/player/playlist_gallery_drawer_test.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Steps:**
1. Add failing widget tests for previous/next arrow paging, a play button only on the centered card, and removal of swipe-instruction text.
2. Add failing integration tests showing a tap on either gallery background or displaced player background closes the open gallery, while horizontal and vertical drags remain gestures.
3. Run the two focused test files and confirm the new expectations fail for the missing UI and dismissal behavior.
4. Give the page a theme-derived gradient/glow background, add 48dp arrow controls wired to the existing `PageController`, and overlay the centered card's play button.
5. Add tap-dismiss surfaces that sit behind interactive content and close the open gallery without intercepting drag gestures.
6. Run the focused tests until they pass.

### Task 2: Build the center-snapping orbit queue

**Files:**
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`
- Modify: `follow/lib/features/player/player_page.dart`
- Test: `follow/test/shared/widgets/player/folded_track_queue_test.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Steps:**
1. Add failing tests that require the current track to start at the viewport center and the queue viewport height to match the record.
2. Add failing tests for signed horizontal arc transforms derived from live scroll position, with the center cover largest and surrounding covers progressively smaller.
3. Add failing tests proving the center title is visible only between pointer-down and pointer-up, and selection fires only after scroll settle.
4. Run the queue tests and confirm each failure is behavioral rather than a setup error.
5. Convert the queue to a stateful fixed-extent scroll viewport with a controller initialized to the current index and symmetric center padding.
6. Calculate cover translation, scale, and opacity from fractional distance to the controller's current item.
7. Track touch/scroll state, show the transient center label while held, snap to the nearest item on release, and invoke `onSelect` once after settling.
8. Make cover taps animate to center and use the same settle-and-play path.
9. Pass the record height from `PlayerPage`, preserve reveal opacity and delayed interaction, and run the focused tests until green.

### Task 3: Rotate the record while playing

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Modify: `follow/lib/features/player/player_page.dart`
- Test: `follow/test/shared/widgets/player/player_cover_art_test.dart`

**Steps:**
1. Add failing tests for angle progression while playing, no progression while paused or dragging, angle preservation after pause, and disabled rotation under reduced motion.
2. Run the cover test and confirm the production widget lacks the playback-driven rotation API.
3. Add `isPlaying` to `PlayerCoverArt`, own a repeating 24-second `AnimationController`, pause without resetting its value, and resume from the stored phase.
4. Suspend the controller during a record drag and resume it after drag completion only when still playing.
5. Rotate only the clipped artwork/grooves/spindle layer, leaving the gesture surface and outer translation stable.
6. Pass the provider's current playback state from `PlayerPage` and run the cover tests until green.

### Task 4: Bound vertical record movement

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Modify: `follow/lib/features/player/player_page.dart`
- Test: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Steps:**
1. Add a failing unit test that drags far vertically and expects reported visual movement to stay inside the configured bound.
2. Add a failing completion test proving the same bounded drag still triggers previous/next using its raw distance.
3. Add an integration assertion that the bound is derived from the visual surface and leaves a safety gap around the record.
4. Run the focused tests and confirm RED.
5. Add `maxVerticalVisualOffset` to `PlayerCoverArt`; clamp only the reported/rendered vertical displacement while retaining raw axis-projected displacement for completion.
6. Compute a conservative maximum from `(surfaceHeight - recordSize) / 2`, subtract the safety gap, and cap it for visual stability.
7. Run the focused tests until green.

### Task 5: Verify the final player state

**Files:**
- Format only the named Dart files and tests.

**Steps:**
1. Run exact Flutter 3.41.6 formatting on the changed Dart files.
2. Run the focused player, gallery, queue, cover, lyrics, and controls tests.
3. Run `/Users/wen/fvm/versions/3.41.6/bin/flutter analyze --no-pub` and require no findings.
4. Run `/Users/wen/fvm/versions/3.41.6/bin/flutter test --no-pub` and require all tests to pass.
5. Run `/Users/wen/fvm/versions/3.41.6/bin/flutter build apk --debug --no-pub` and capture the artifact path and checksum.
6. Confirm the build did not modify `follow/android/gradle.properties` or `follow/pubspec.lock`.
7. Run `git diff --check`, inspect only the scoped player diffs, and report device verification separately.
