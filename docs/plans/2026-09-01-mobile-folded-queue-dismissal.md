# Mobile Folded Queue Dismissal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the folded queue auto-close after two seconds of inactivity, dismiss it for every external player operation, restore the bottom-sheet queue button, and toggle playback when the record is tapped.

**Architecture:** Keep transient visibility and timer ownership in `PlayerPage`; expose semantic interaction lifecycle callbacks from `FoldedTrackQueue` and pointer/tap callbacks from `PlayerCoverArt`. Reuse `PlayQueueSheet` for persistent queue management and preserve the existing record gesture recognizer and playback providers.

**Tech Stack:** Flutter, Dart `Timer`, Riverpod, Flutter widget tests

---

### Task 1: Report folded-queue interaction lifecycle

**Files:**
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`
- Test: `follow/test/shared/widgets/player/folded_track_queue_test.dart`

**Step 1: Write failing lifecycle tests**

Extend the queue test harness with `onInteractionStart` and
`onInteractionSettled` counters. Add tests that:

- pointer-down reports start immediately;
- releasing a drag reports settled only after scroll snapping completes;
- tapping an item reports one start and one settle;
- programmatic recentering after `currentTrackId` changes does not report user
  interaction.

**Step 2: Run the focused test and verify the regression**

Run:

```bash
cd follow && fvm flutter test --no-pub test/shared/widgets/player/folded_track_queue_test.dart
```

Expected: FAIL because the callbacks do not exist.

**Step 3: Add minimal lifecycle callbacks**

Add optional callbacks:

```dart
final VoidCallback? onInteractionStart;
final VoidCallback? onInteractionSettled;
```

Call `onInteractionStart` from the queue listener's pointer-down path. Track
whether a user interaction is active, and call `onInteractionSettled` after
`_snapAndSelect` completes for that interaction. Clear the active flag so
scroll notifications caused by programmatic recentering cannot restart the
page timer.

**Step 4: Run the focused test**

Run the command from Step 2. Expected: PASS.

### Task 2: Add record pointer-start and tap contracts

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Test: `follow/test/shared/widgets/player/player_cover_art_test.dart`

**Step 1: Write failing gesture-arbitration tests**

Add callback counters and prove:

- pointer-down reports interaction start before pointer-up;
- a stationary tap calls `onTap` exactly once;
- a completed horizontal or vertical drag reports interaction start but never
  calls `onTap`;
- the semantics label describes tap-to-play or tap-to-pause as well as cardinal
  swipe behavior.

**Step 2: Run the focused test and verify failure**

Run:

```bash
cd follow && fvm flutter test --no-pub test/shared/widgets/player/player_cover_art_test.dart
```

Expected: FAIL because record pointer/tap callbacks are absent.

**Step 3: Implement the minimal record API**

Add:

```dart
final VoidCallback? onInteractionStart;
final VoidCallback? onTap;
```

Wrap the existing gesture surface in a `Listener` for pointer-down, and pass
`onTap` to the existing `GestureDetector`. Keep the single pan recognizer,
dominant-axis lock, settle animation, and one-track-per-gesture behavior
unchanged. Update semantics using `isPlaying` to announce the tap action.

**Step 4: Run the focused test**

Run the command from Step 2. Expected: PASS.

### Task 3: Give volume operations an external-dismiss hook

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_volume_control.dart`
- Test: `follow/test/shared/widgets/player/player_volume_control_test.dart`

**Step 1: Write failing callback tests**

Pump `PlayerVolumeControl(onInteractionStart: ...)` and prove both mute-button
tap and slider drag call the callback at interaction start while retaining
their current volume behavior.

**Step 2: Run the focused test and verify failure**

Run:

```bash
cd follow && fvm flutter test --no-pub test/shared/widgets/player/player_volume_control_test.dart
```

Expected: FAIL because the constructor has no callback.

**Step 3: Implement the hook**

Add an optional `onInteractionStart`. Invoke it before mute toggling and from
the slider's `onChangeStart`. Do not move volume state or provider ownership.

**Step 4: Run the focused test**

Run the command from Step 2. Expected: PASS.

### Task 4: Implement two-second queue dismissal and restore the sheet

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Replace obsolete expectations with failing behavior tests**

Update the integration harness/tests to prove:

- right-swiping the record opens the folded queue and starts a two-second timer;
- the queue remains open just before two seconds and closes at two seconds;
- queue pointer-down cancels the timer, and settling restarts a full two-second
  interval;
- record pointer-down dismisses immediately, a tap toggles playback, and a drag
  retains the existing swipe action without also toggling;
- mode, previous, play/pause, next, progress, volume, playlist pull start,
  app-bar actions, and back dismiss an open folded queue;
- tapping `当前播放队列` displays `PlayQueueSheet` and does not open the folded
  queue;
- reopening after a track change centers the current track.

Replace the now-invalid tests that expect a short record swipe or
below-threshold playlist pull to keep the queue open.

**Step 2: Run the integration test and verify failure**

Run:

```bash
cd follow && fvm flutter test --no-pub test/features/player/interactive_lyrics_integration_test.dart
```

Expected: FAIL on timer, record tap, dismissal, and bottom-sheet expectations.

**Step 3: Add timer ownership to `PlayerPage`**

Import `dart:async` and add:

```dart
static const _foldedQueueIdleDuration = Duration(seconds: 2);
Timer? _foldedQueueAutoCloseTimer;
bool _foldedQueueInteractionActive = false;
```

Implement helpers to cancel, schedule, and restart the timer. The callback must
check `mounted`, `_queueOpen`, and `!_foldedQueueInteractionActive`. Cancel it
from `_closeQueue`, page disposal, and every external interaction. Opening the
queue starts the timer; queue start cancels it; queue settle starts it again.

**Step 4: Restore the bottom-sheet queue action**

Import `PlayQueueSheet` and add:

```dart
void _showPlayQueue(BuildContext context) {
  _closeQueue();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PlayQueueSheet(),
  );
}
```

Pass this helper to `PlayerMainControls.onShowQueue` instead of `_showQueue`.
The record's right swipe remains the only way to reveal the folded queue.

**Step 5: Wire all external player operations**

Use one `_dismissFoldedQueueForExternalInteraction` helper before existing
actions. Wire it to:

- `PlayerCoverArt.onInteractionStart`;
- record `onTap`, followed by play/pause;
- a pointer listener around `PlayerMainControls`;
- progress slider `onChangeStart`;
- `PlayerVolumeControl.onInteractionStart`;
- playlist pull start;
- app-bar back and more actions;
- PopScope/back handling.

Folded-queue callbacks only cancel/restart the timer and do not dismiss during
their own active interaction.

**Step 6: Add natural endpoint motion**

Keep direct-manipulation reveal progress immediate during a horizontal record
drag. Animate only the open/closed endpoints over approximately 220 ms with
`Curves.easeOutCubic`, fading/receding queue content while the existing record
container returns to center. Reduced-motion mode uses zero duration.

Do not bind the record's vertical drag offset to the queue scroll controller.

**Step 7: Run the integration test**

Run the command from Step 2. Expected: PASS.

### Task 5: Verify the scoped player change

**Files:**
- Verify only; do not modify unrelated dirty paths

**Step 1: Run all focused player tests together**

```bash
cd follow && fvm flutter test --no-pub \
  test/shared/widgets/player/folded_track_queue_test.dart \
  test/shared/widgets/player/player_cover_art_test.dart \
  test/shared/widgets/player/player_volume_control_test.dart \
  test/shared/widgets/player/player_main_controls_test.dart \
  test/shared/widgets/play_queue_sheet_test.dart \
  test/features/player/interactive_lyrics_integration_test.dart
```

Expected: all tests PASS.

**Step 2: Run scoped static analysis**

```bash
cd follow && fvm flutter analyze --no-pub \
  lib/features/player/player_page.dart \
  lib/shared/widgets/player/folded_track_queue.dart \
  lib/shared/widgets/player/player_cover_art.dart \
  lib/shared/widgets/player/player_volume_control.dart \
  test/features/player/interactive_lyrics_integration_test.dart \
  test/shared/widgets/player/folded_track_queue_test.dart \
  test/shared/widgets/player/player_cover_art_test.dart \
  test/shared/widgets/player/player_volume_control_test.dart
```

Expected: `No issues found!`

**Step 3: Run the full Flutter suite**

```bash
cd follow && fvm flutter test --no-pub
```

Expected: all tests PASS.

**Step 4: Review only the scoped diff**

```bash
git diff --check -- \
  docs/plans/2026-09-01-mobile-folded-queue-dismissal-design.md \
  docs/plans/2026-09-01-mobile-folded-queue-dismissal.md \
  follow/lib/features/player/player_page.dart \
  follow/lib/shared/widgets/player/folded_track_queue.dart \
  follow/lib/shared/widgets/player/player_cover_art.dart \
  follow/lib/shared/widgets/player/player_volume_control.dart \
  follow/test/features/player/interactive_lyrics_integration_test.dart \
  follow/test/shared/widgets/player/folded_track_queue_test.dart \
  follow/test/shared/widgets/player/player_cover_art_test.dart \
  follow/test/shared/widgets/player/player_volume_control_test.dart
```

Inspect `git status --short` and the scoped diff. Do not stage, commit, push,
merge, clean, deploy, or touch production.
