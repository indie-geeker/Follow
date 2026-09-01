# Lyrics Return Timer Race Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent an earlier lyric auto-return timer from interrupting a new touch or trackpad drag.

**Architecture:** Treat pointer-down and pan-zoom-start as ownership boundaries for lyric browsing. Cancel and clear the pending inactivity timer immediately, while retaining the existing pointer-end and scroll-end paths that start a fresh full delay.

**Tech Stack:** Flutter, Dart, Flutter Widget Tests

---

### Task 1: Prove the stale timer race

**Files:**
- Modify: `follow/test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

**Step 1: Write the failing test**

Add a Widget test that performs a first drag, waits until just before the three-second deadline, starts and holds a second gesture, then advances past the old deadline plus return animation. Assert that `lyricsCenterPlayKey` remains visible while the second pointer is down.

**Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart --plain-name "a new held drag cancels the previous inactivity timer immediately"
```

Expected: FAIL because the old timer returns the view to playback while the second pointer remains down.

### Task 2: Cancel the timer at new interaction start

**Files:**
- Modify: `follow/lib/shared/widgets/lyrics/interactive_lyrics_view.dart`
- Test: `follow/test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

**Step 1: Write minimal implementation**

Add a small helper that cancels and clears `_inactivityTimer`, and call it from `_handlePointerDown` and `_handlePanZoomStart` before existing return-interruption logic.

**Step 2: Run the focused test**

Run the command from Task 1.

Expected: PASS. After releasing the second gesture, verify a new full inactivity delay still returns to playback.

### Task 3: Verify regression safety

**Files:**
- Verify: `follow/lib/shared/widgets/lyrics/interactive_lyrics_view.dart`
- Verify: `follow/test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

**Step 1: Format the target files**

```bash
dart format lib/shared/widgets/lyrics/interactive_lyrics_view.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart
```

**Step 2: Run lyric widget tests**

```bash
flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart
```

**Step 3: Run static analysis and the full suite**

```bash
flutter analyze
flutter test
```

**Step 4: Review the scoped diff**

Confirm the production change only affects inactivity-timer ownership and the test only adds the race reproduction. Preserve all pre-existing enhanced-LRC and server test changes.

