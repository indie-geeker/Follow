# Player Popup Edge and Queue Gesture Gate Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the playback-mode popup fully visible on narrow screens and make the first record interaction while the folded queue is open close only that queue.

**Architecture:** Retain the existing anchored overlay, reduce its content width, and compute the smallest horizontal correction needed to stay inside an 8px viewport margin. Add an interaction-consumption callback to `PlayerCoverArt` so the widget can gate an entire pointer sequence before visual movement or action callbacks occur.

**Tech Stack:** Flutter, Riverpod, Overlay/CompositedTransformFollower, flutter_test.

---

### Task 1: Make the mode popup edge-aware

**Files:**
- Modify: `follow/test/shared/widgets/player/player_mode_control_test.dart`
- Modify: `follow/lib/shared/widgets/player/player_mode_control.dart`

**Step 1: Write the failing test**

- Pump `PlayerModeControl` near the left edge on a 360px viewport.
- Open the popup and assert its left edge is at least 8px and right edge is at most 352px.
- Keep the existing center-alignment assertion for a button with sufficient surrounding space.
- Assert all three labels remain present and each item stays at least 48px high.

**Step 2: Run test to verify it fails**

Run: `fvm flutter test --no-pub test/shared/widgets/player/player_mode_control_test.dart`

Expected: FAIL because the current 168px popup extends past the left viewport edge.

**Step 3: Write minimal implementation**

- Reduce popup width to 128px.
- Reduce item horizontal padding to 8px and compact the check/gap widths.
- Resolve the anchor center from `playerModeButtonAnchorKey` and add only the horizontal follower correction needed to keep the popup inside an 8px screen margin.

**Step 4: Run test to verify it passes**

Run: `fvm flutter test --no-pub test/shared/widgets/player/player_mode_control_test.dart test/shared/widgets/player/player_main_controls_test.dart`

Expected: PASS.

### Task 2: Consume the first record interaction while the queue is open

**Files:**
- Modify: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Modify: `follow/lib/features/player/player_page.dart`

**Step 1: Write the failing widget test**

- Add an interaction-consumption callback to the cover-art test harness.
- Assert a consumed tap invokes neither `onTap` nor drag visuals.
- Assert consumed swipes in all four directions invoke no swipe callback and produce no visual offset.
- Assert the next non-consumed interaction behaves normally.

**Step 2: Write the failing integration tests**

- Open the folded queue, tap the record, and assert the queue closes without play/pause.
- Reopen the queue and swipe vertically/horizontally; assert no track navigation or lyric switch occurs.
- After the queue is closed, repeat representative gestures and assert their original actions still run.

**Step 3: Run tests to verify they fail**

Run: `fvm flutter test --no-pub test/shared/widgets/player/player_cover_art_test.dart test/features/player/interactive_lyrics_integration_test.dart`

Expected: FAIL because pointer-down currently closes the queue but the same interaction continues to trigger record actions.

**Step 4: Write minimal implementation**

- Add `bool Function()? onInteractionAttempt` to `PlayerCoverArt`.
- Capture its result at pointer-down and suppress pan start/update/end/cancel actions for the entire consumed pointer sequence.
- Keep semantic activation guarded in `PlayerPage` because it bypasses the pointer recognizer.
- In `PlayerPage`, return `true` and close the queue when the queue is visible; otherwise return `false`.

**Step 5: Run tests to verify they pass**

Run: `fvm flutter test --no-pub test/shared/widgets/player/player_cover_art_test.dart test/features/player/interactive_lyrics_integration_test.dart`

Expected: PASS.

### Task 3: Verify the player and repository diff

**Files:**
- Verify all files above.

**Step 1: Analyze the scoped files**

Run: `fvm flutter analyze --no-pub lib/shared/widgets/player/player_mode_control.dart lib/shared/widgets/player/player_cover_art.dart lib/features/player/player_page.dart test/shared/widgets/player/player_mode_control_test.dart test/shared/widgets/player/player_cover_art_test.dart test/features/player/interactive_lyrics_integration_test.dart`

Expected: No issues found.

**Step 2: Run focused player tests**

Run: `fvm flutter test --no-pub test/shared/widgets/player test/features/player/interactive_lyrics_integration_test.dart`

Expected: PASS.

**Step 3: Run the complete Flutter suite**

Run: `fvm flutter test --no-pub`

Expected: PASS.

**Step 4: Check diff hygiene**

Run: `git diff --check`

Expected: exit 0. Confirm `follow/pubspec.lock` is unchanged and do not commit, push, or deploy.
