# Folded Queue Timer and Play Mode Popup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the folded queue open until a real list drag settles or an external operation dismisses it, and add a centered, selectable three-mode popup above the playback-mode button.

**Architecture:** `FoldedTrackQueue` reports whether an interaction contained real vertical pointer scrolling, while `PlayerPage` schedules auto-close only from that scroll-settled signal. A dedicated `PlayerModeControl` owns an anchored `OverlayEntry`, one two-second timer, and entry/exit animation while reading mode state directly from Riverpod.

**Tech Stack:** Flutter, Dart `Timer`, Riverpod, `OverlayEntry`, `CompositedTransformTarget`/`CompositedTransformFollower`, widget tests

---

### Task 1: Distinguish queue taps from real list scrolling

**Files:**
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`
- Test: `follow/test/shared/widgets/player/folded_track_queue_test.dart`

**Step 1: Write failing interaction tests**

Extend the queue test harness with an `onScrollSettled` counter. Prove that:

- tapping a cover reports interaction start but not scroll settle;
- a vertical pointer drag reports scroll settle once, after snapping;
- programmatic current-track recentering reports neither user event;
- pointer-down still reports immediately so an existing page timer can be
  cancelled.

**Step 2: Verify RED**

```bash
cd follow && fvm flutter test --no-pub test/shared/widgets/player/folded_track_queue_test.dart
```

Expected: FAIL because no scroll-specific callback exists.

**Step 3: Implement minimal drag classification**

Add an optional `onScrollSettled` callback. Track cumulative pointer movement
for the active interaction and mark it as a real list drag only after vertical
movement passes the existing gesture slop. When `_snapAndSelect` completes,
call `onScrollSettled` only for a real drag. Keep `onInteractionStart` for every
pointer-down. Tap-driven `animateTo` and programmatic recentering must not count
as scrolls.

Remove the page's dependency on the generic settled callback once the new
contract is wired.

**Step 4: Verify GREEN**

Run the command from Step 2. Expected: PASS.

### Task 2: Change folded-queue timer arming

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Write failing timer regressions**

Update integration tests to prove:

- opening the folded queue and pumping beyond two seconds keeps it visible;
- tapping a queue item and pumping beyond two seconds keeps it visible;
- a real vertical queue drag starts the two-second timer after snap settle;
- a new queue pointer interaction cancels a running timer;
- all external player operations still dismiss immediately.

**Step 2: Verify RED**

```bash
cd follow && fvm flutter test --no-pub test/features/player/interactive_lyrics_integration_test.dart
```

Expected: FAIL because `_showQueue` currently arms the timer and generic queue
settle cannot distinguish taps from drags.

**Step 3: Implement minimal timer changes**

Remove `_scheduleFoldedQueueAutoClose()` from `_showQueue`. Keep
`_handleFoldedQueueInteractionStart` as immediate cancellation, and schedule
only from the new queue `onScrollSettled` callback. Preserve immediate external
dismissal and the existing 220ms queue animation.

**Step 4: Verify GREEN**

Run the command from Step 2. Expected: PASS.

### Task 3: Build the anchored playback-mode popup

**Files:**
- Create: `follow/lib/shared/widgets/player/player_mode_control.dart`
- Modify: `follow/lib/shared/widgets/player/player_main_controls.dart`
- Test: `follow/test/shared/widgets/player/player_mode_control_test.dart`
- Test: `follow/test/shared/widgets/player/player_main_controls_test.dart`

**Step 1: Write failing popup tests**

Create component tests proving:

- the button starts with the provider's icon and tooltip;
- tapping the button advances mode and shows all three rows;
- exactly the active row has a check mark;
- tapping a row selects that exact mode and keeps the popup visible;
- button and item taps each restart the full two-second timeout;
- the popup disappears after two idle seconds;
- popup center X equals mode-button center X within one logical pixel;
- each item is at least 48dp high and has selected semantics.

Update the main-controls test to find the extracted component without changing
the independently centered transport controls.

**Step 2: Verify RED**

```bash
cd follow && fvm flutter test --no-pub \
  test/shared/widgets/player/player_mode_control_test.dart \
  test/shared/widgets/player/player_main_controls_test.dart
```

Expected: FAIL because `PlayerModeControl` does not exist.

**Step 3: Implement `PlayerModeControl`**

Create a `ConsumerStatefulWidget` with:

```dart
static const popupDuration = Duration(seconds: 2);
final LayerLink _layerLink = LayerLink();
OverlayEntry? _overlayEntry;
Timer? _hideTimer;
```

Use `CompositedTransformTarget` around the existing 48dp
`PlayerControlButton`. Insert an overlay entry containing a fixed-width popup
through `CompositedTransformFollower` with:

```dart
targetAnchor: Alignment.topCenter,
followerAnchor: Alignment.bottomCenter,
offset: const Offset(0, -8),
```

This anchor pair is the source of truth for exact horizontal centering. The
popup contains three fixed-height item rows and a fixed leading slot for the
active check mark. Use the provider for icon, tooltip, selection, and direct
item changes; never duplicate mode state locally.

Use one animation controller for fade plus a small downward retreat. Every
button/item activation cancels and replaces the timer. Item selection keeps the
entry mounted. Dispose removes the entry and timer safely.

**Step 4: Integrate without moving transport controls**

Replace only the left `PlayerControlButton` in `PlayerMainControls` with
`PlayerModeControl`. Keep the full-width `Stack`, centered transport row, and
right queue action unchanged.

**Step 5: Verify GREEN**

Run the command from Step 2. Expected: PASS.

### Task 4: Verify the complete player change

**Files:**
- Verify the files above and existing focused player paths only

**Step 1: Run focused player tests**

```bash
cd follow && fvm flutter test --no-pub \
  test/shared/widgets/player/folded_track_queue_test.dart \
  test/shared/widgets/player/player_mode_control_test.dart \
  test/shared/widgets/player/player_main_controls_test.dart \
  test/features/player/interactive_lyrics_integration_test.dart
```

Expected: all tests PASS.

**Step 2: Run scoped analysis**

```bash
cd follow && fvm flutter analyze --no-pub \
  lib/features/player/player_page.dart \
  lib/shared/widgets/player/folded_track_queue.dart \
  lib/shared/widgets/player/player_mode_control.dart \
  lib/shared/widgets/player/player_main_controls.dart \
  test/shared/widgets/player/folded_track_queue_test.dart \
  test/shared/widgets/player/player_mode_control_test.dart \
  test/shared/widgets/player/player_main_controls_test.dart \
  test/features/player/interactive_lyrics_integration_test.dart
```

Expected: `No issues found!`

**Step 3: Run the full Flutter suite**

```bash
cd follow && fvm flutter test --no-pub
```

Expected: all tests PASS.

**Step 4: Review scope and formatting**

Run `git diff --check` against only the named source, test, and plan files.
Confirm `pubspec.lock` remains unchanged. Do not stage, commit, push, merge,
clean, deploy, or touch production.
