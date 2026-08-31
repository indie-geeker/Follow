# Interactive Lyrics Scrolling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add one shared mobile-and-desktop lyrics view that supports uninterrupted manual browsing, center-line seeking, and automatic return to the playing lyric after three seconds.

**Architecture:** Move lyric rendering and transient scroll state out of `PlayerPage` and `LyricsOverlay` into a shared stateful widget. Keep playback state in the existing Riverpod providers, use rendered row geometry for exact center selection, and guard programmatic scrolling so it cannot be mistaken for user input.

**Tech Stack:** Flutter, Dart 3.10, Riverpod 3, Flutter widget tests

---

## Preconditions

- Execute in an isolated worktree created from commit `6c17f28` or later.
- Follow @superpowers:test-driven-development for every task.
- Run commands from `follow/` unless stated otherwise.
- Never stage the unrelated untracked 2026-08-30 playback-metadata plans.

### Task 1: Define Deterministic Center-Line Selection

**Files:**

- Create: `lib/shared/widgets/lyrics/lyrics_scroll_geometry.dart`
- Create: `test/shared/widgets/lyrics/lyrics_scroll_geometry_test.dart`

**Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_scroll_geometry.dart';

void main() {
  test('selects the visible row closest to center', () {
    expect(
      findNearestLyricIndex(
        rows: const [
          VisibleLyricGeometry(index: 2, center: 80),
          VisibleLyricGeometry(index: 3, center: 126),
          VisibleLyricGeometry(index: 4, center: 172),
        ],
        viewportCenter: 120,
        scrollDirection: 0,
      ),
      3,
    );
  });

  test('uses direction then source order to break equal distances', () {
    const rows = [
      VisibleLyricGeometry(index: 4, center: 100),
      VisibleLyricGeometry(index: 5, center: 140),
    ];
    expect(
      findNearestLyricIndex(
        rows: rows,
        viewportCenter: 120,
        scrollDirection: 1,
      ),
      5,
    );
    expect(
      findNearestLyricIndex(
        rows: rows,
        viewportCenter: 120,
        scrollDirection: -1,
      ),
      4,
    );
    expect(
      findNearestLyricIndex(
        rows: rows,
        viewportCenter: 120,
        scrollDirection: 0,
      ),
      4,
    );
  });

  test('returns null without rendered rows', () {
    expect(
      findNearestLyricIndex(
        rows: const [],
        viewportCenter: 120,
        scrollDirection: 0,
      ),
      isNull,
    );
  });
}
```

**Step 2: Prove the tests fail**

Run: `flutter test test/shared/widgets/lyrics/lyrics_scroll_geometry_test.dart`

Expected: FAIL because the helper does not exist.

**Step 3: Add the minimal helper**

```dart
import 'package:flutter/foundation.dart';

@immutable
class VisibleLyricGeometry {
  const VisibleLyricGeometry({required this.index, required this.center});

  final int index;
  final double center;
}

int? findNearestLyricIndex({
  required Iterable<VisibleLyricGeometry> rows,
  required double viewportCenter,
  required int scrollDirection,
}) {
  VisibleLyricGeometry? nearest;
  double? nearestDistance;
  for (final row in rows) {
    final distance = (row.center - viewportCenter).abs();
    if (nearest == null || distance < nearestDistance!) {
      nearest = row;
      nearestDistance = distance;
      continue;
    }
    if (distance != nearestDistance) continue;
    if (scrollDirection > 0 && row.index > nearest.index) {
      nearest = row;
    } else if (scrollDirection < 0 && row.index < nearest.index) {
      nearest = row;
    } else if (scrollDirection == 0 && row.index < nearest.index) {
      nearest = row;
    }
  }
  return nearest?.index;
}
```

**Step 4: Format and prove the tests pass**

Run: `dart format lib/shared/widgets/lyrics/lyrics_scroll_geometry.dart test/shared/widgets/lyrics/lyrics_scroll_geometry_test.dart`

Run: `flutter test test/shared/widgets/lyrics/lyrics_scroll_geometry_test.dart`

Expected: three tests PASS.

**Step 5: Commit**

```bash
git add lib/shared/widgets/lyrics/lyrics_scroll_geometry.dart test/shared/widgets/lyrics/lyrics_scroll_geometry_test.dart
git commit -m "test: define lyric center selection"
```

### Task 2: Build the Shared Follow-Mode View

**Files:**

- Create: `lib/shared/widgets/lyrics/interactive_lyrics_view.dart`
- Create: `test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

**Step 1: Write a reusable test harness**

Use a fixed 360-by-300 viewport and a `ValueNotifier<int>` so the current index
can change without recreating the widget. Define six `LyricLine` values at
five-second intervals and collect values passed to `onSeek`.

```dart
const testLyrics = [
  LyricLine(timestamp: Duration(seconds: 0), text: '第 0 行'),
  LyricLine(timestamp: Duration(seconds: 5), text: '第 1 行'),
  LyricLine(timestamp: Duration(seconds: 10), text: '第 2 行'),
  LyricLine(timestamp: Duration(seconds: 15), text: '第 3 行'),
  LyricLine(timestamp: Duration(seconds: 20), text: '第 4 行'),
  LyricLine(timestamp: Duration(seconds: 25), text: '第 5 行'),
];
```

Pump `InteractiveLyricsView` through `ProviderScope`, `MaterialApp`, `Scaffold`,
and `SizedBox`. Pass `AsyncData(testLyrics)`, black foreground, and an async
`onSeek` callback that records the duration.

**Step 2: Write failing follow-mode tests**

Assert that current row 2 is within two logical pixels of
`lyricsViewportKey`'s center and `lyricsCenterPlayKey` is absent. Change the
notifier from 1 to 4, pump 280 milliseconds, and assert row 4 becomes centered.

Run: `flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: FAIL because the widget and public test keys do not exist.

**Step 3: Implement the widget shell**

Expose:

```dart
const lyricsViewportKey = Key('interactive-lyrics-viewport');
const lyricsCenterPlayKey = Key('interactive-lyrics-center-play');

class InteractiveLyricsView extends StatefulWidget {
  const InteractiveLyricsView({
    super.key,
    required this.lyrics,
    required this.currentIndex,
    required this.foregroundColor,
    required this.onSeek,
    this.inactivityDelay = const Duration(seconds: 3),
    this.followDuration = const Duration(milliseconds: 280),
    this.returnDuration = const Duration(milliseconds: 400),
    this.seekDuration = const Duration(milliseconds: 220),
  });

  final AsyncValue<List<LyricLine>> lyrics;
  final int currentIndex;
  final Color foregroundColor;
  final Future<void> Function(Duration) onSeek;
  final Duration inactivityDelay;
  final Duration followDuration;
  final Duration returnDuration;
  final Duration seekDuration;
}
```

The state owns one `ScrollController`, one viewport `GlobalKey`, stable row
`GlobalKey` values, a nullable timer, browse/selection flags, a programmatic
scroll flag, and a monotonically increasing scroll-operation token.

Render `AsyncValue.when` inside the component. Use `LyricsFailureView` for
errors and preserve `暂无歌词` for empty data. Render data as a keyed
`ListView.builder` in a `Stack`; rows have `ValueKey('lyric-row-$index')`, a
minimum 48-pixel height, wrapping text, and half-viewport top/bottom padding.

Implement exact positioning with
`RenderAbstractViewport.getOffsetToReveal(row, 0.5)`. If a distant row is not
laid out, jump to a clamped estimated vicinity, wait one frame, then use its
rendered geometry. Only call this from initial layout and `didUpdateWidget` when
`currentIndex` changes outside browse mode.

**Step 4: Prove focused tests pass**

Run: `dart format lib/shared/widgets/lyrics/interactive_lyrics_view.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Run: `flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: follow-mode tests PASS.

**Step 5: Commit**

```bash
git add lib/shared/widgets/lyrics/interactive_lyrics_view.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart
git commit -m "feat: add shared lyrics follow view"
```

### Task 3: Add Browse Mode and the Three-Second Return

**Files:**

- Modify: `lib/shared/widgets/lyrics/interactive_lyrics_view.dart`
- Modify: `test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

**Step 1: Write failing interaction tests**

With twelve lyric rows, drag the keyed viewport by `Offset(0, -160)` and assert
the center control appears. Record the scroll offset, change `currentIndex`,
pump 500 milliseconds, and assert the offset has not moved. Pump 2.9 seconds and
assert the control remains; pump 100 milliseconds plus the 400-millisecond
return animation and assert it disappears and the playing row is centered.

Add separate tests proving:

- a second interaction at 2.9 seconds restarts the timer;
- a `PointerScrollEvent` enters browse mode;
- user input cancels an in-progress return animation;
- programmatic follow notifications never show browse controls.

Run: `flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: FAIL because browse tracking is not implemented.

**Step 2: Implement input classification**

Add `dart:async`, `flutter/gestures.dart`, and `flutter/rendering.dart`. Wrap the
list in `Listener` and `NotificationListener<ScrollNotification>`.

- Pointer down, pointer-wheel signal, and pan/zoom start call `_beginBrowsing`.
- User `ScrollUpdateNotification` records pixel direction and schedules a
  post-frame center calculation.
- `ScrollEndNotification` and idle `UserScrollNotification` start a new
  three-second timer.
- Every additional wheel or trackpad signal restarts the timer.
- Programmatic notifications exit without changing browse state.

`_beginBrowsing` cancels the timer, invalidates the scroll-operation token, and
stops an active programmatic animation with `jumpTo(controller.offset)`.
`_returnToPlayback` centers the latest `widget.currentIndex` over 400
milliseconds and hides the indicator only if it was not interrupted.

**Step 3: Prove tests pass and commit**

Run: `dart format lib/shared/widgets/lyrics/interactive_lyrics_view.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Run: `flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: all follow and browse tests PASS.

```bash
git add lib/shared/widgets/lyrics/interactive_lyrics_view.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart
git commit -m "feat: pause lyric following during browsing"
```

### Task 4: Add Center Seeking and Accessibility

**Files:**

- Modify: `lib/shared/widgets/lyrics/interactive_lyrics_view.dart`
- Modify: `test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

**Step 1: Write failing seek tests**

After scrolling to a known line, assert:

```dart
expect(find.byTooltip('从此处播放'), findsOneWidget);
expect(find.bySemanticsLabel(startsWith('从此处播放：')), findsOneWidget);
expect(
  tester.getSize(find.byKey(lyricsCenterPlayKey)).shortestSide,
  greaterThanOrEqualTo(44),
);
```

Tap the arrow and verify `onSeek` receives the center-selected timestamp and the
component returns to follow mode. Tap `ValueKey('lyric-row-4')` and verify direct
line seeking still works. Make `onSeek` throw and verify the widget remains in
browse mode without a disposal error.

Run: `flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: FAIL because selection and the arrow are absent.

**Step 2: Implement rendered center selection**

Convert mounted row render boxes to viewport-local centers, create
`VisibleLyricGeometry` values, and call `findNearestLyricIndex` after each user
scroll update.

While browsing, overlay a vertically centered `IconButton` using
`Icons.play_arrow_rounded`, a 44-by-44 minimum target, tooltip `从此处播放`,
semantic label `从此处播放：<歌词>`, click cursor, and a low-opacity guide that
does not intercept events.

Implement one `_seekToIndex` path for arrow and row activation. It awaits only
`widget.onSeek`, centers the target over 220 milliseconds, and then returns to
follow mode. It must never call play or pause. If seek throws, retain browse
state and selection.

Style priority is: playing line, center-selected line, normal line. If playing
and selected are the same, render only the playing style.

**Step 3: Prove tests pass and commit**

Run: `dart format lib/shared/widgets/lyrics/interactive_lyrics_view.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Run: `flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: seek, semantics, hit-area, and style tests PASS.

```bash
git add lib/shared/widgets/lyrics/interactive_lyrics_view.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart
git commit -m "feat: seek from centered lyric"
```

### Task 5: Harden Geometry and Lifecycle

**Files:**

- Modify: `lib/shared/widgets/lyrics/interactive_lyrics_view.dart`
- Modify: `test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

**Step 1: Write failing edge tests**

Cover first and last rows, a long wrapped lyric at 220-pixel width, lyrics-list
replacement, disposal with a pending timer, `disableAnimations: true`, loading,
empty, error, and a single lyric. Assert rendered centers, not estimated offsets.

Run: `flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: lifecycle, reduced-motion, or boundary tests FAIL.

**Step 2: Implement hardening**

- On lyrics replacement, cancel timers and scrolling, rebuild row keys, clear
  selection, and follow the new current index.
- Cancel timer and invalidate scroll operations before disposing the controller.
- Guard every callback and async completion with `mounted` and operation token.
- Clamp every estimated and exact offset to min/max scroll extent.
- Use `MediaQuery.disableAnimations` to replace animation durations with zero.
- Do not attach browse behavior for zero or one lyric.

**Step 3: Prove tests pass and commit**

Run: `dart format lib/shared/widgets/lyrics/interactive_lyrics_view.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Run: `flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: all shared-widget tests PASS without pending-timer exceptions.

```bash
git add lib/shared/widgets/lyrics/interactive_lyrics_view.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart
git commit -m "test: harden interactive lyrics lifecycle"
```

### Task 6: Integrate Mobile PlayerPage

**Files:**

- Modify: `lib/features/player/player_page.dart:21-31`
- Modify: `lib/features/player/player_page.dart:165-179`
- Modify: `lib/features/player/player_page.dart:404-463`
- Create: `test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Write a failing mobile source guard**

Read `player_page.dart` and assert it contains `InteractiveLyricsView(` and no
longer contains `_lyricsScrollController` or `currentLyricIdx * 48.0`.

Run: `flutter test test/features/player/interactive_lyrics_integration_test.dart`

Expected: FAIL against the current mobile implementation.

**Step 2: Replace the mobile list**

Import the shared widget, remove the controller and post-frame auto-scroll block,
and reduce `_buildLyricsPage` to:

```dart
return InteractiveLyricsView(
  key: ValueKey('mobile-lyrics-$trackId'),
  lyrics: lyricsAsync,
  currentIndex: currentLyricIdx,
  foregroundColor: _foregroundColor(context),
  onSeek: audioService.seek,
);
```

Pass `currentTrack.id`. Keep the `PageView`, indicators, cover, progress bar,
volume, and playback controls unchanged.

**Step 3: Prove the mobile guard and shared tests pass**

Run: `dart format lib/features/player/player_page.dart test/features/player/interactive_lyrics_integration_test.dart`

Run: `flutter test test/features/player/interactive_lyrics_integration_test.dart --plain-name "mobile player uses the shared interactive lyrics view"`

Run: `flutter test test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: all commands PASS.

**Step 4: Commit**

```bash
git add lib/features/player/player_page.dart test/features/player/interactive_lyrics_integration_test.dart
git commit -m "refactor: share mobile lyric interactions"
```

### Task 7: Integrate Desktop LyricsOverlay

**Files:**

- Modify: `lib/features/player/lyrics_overlay.dart:23-47`
- Modify: `lib/features/player/lyrics_overlay.dart:95-110`
- Modify: `lib/features/player/lyrics_overlay.dart:272-413`
- Modify: `test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Write a failing desktop source guard**

Read `lyrics_overlay.dart` and assert it contains `InteractiveLyricsView(` and
no longer contains `_lyricsScrollController` or `currentLyricIdx * 48.0`.

Run: `flutter test test/features/player/interactive_lyrics_integration_test.dart --plain-name "desktop overlay uses the shared interactive lyrics view"`

Expected: FAIL against the current desktop implementation.

**Step 2: Replace the desktop list**

Import the shared widget, remove the controller and post-frame auto-scroll block,
and make `_buildLyricsList` return:

```dart
return InteractiveLyricsView(
  key: ValueKey('desktop-lyrics-$trackId'),
  lyrics: lyricsAsync,
  currentIndex: currentLyricIdx,
  foregroundColor: _foregroundColor(context),
  onSeek: audioService.seek,
);
```

Pass `currentTrack?.id` from both wide and narrow layouts. Keep cover, track
information, volume, progress, controls, and overlay animation unchanged.

**Step 3: Prove integration passes**

Run: `dart format lib/features/player/lyrics_overlay.dart test/features/player/interactive_lyrics_integration_test.dart`

Run: `flutter test test/features/player/interactive_lyrics_integration_test.dart test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`

Expected: mobile, desktop, and shared-widget tests PASS.

**Step 4: Commit**

```bash
git add lib/features/player/lyrics_overlay.dart test/features/player/interactive_lyrics_integration_test.dart
git commit -m "refactor: share desktop lyric interactions"
```

### Task 8: Verify the Complete Flutter Client

**Files:** Verify only; change only feature files if a check reveals a related problem.

**Step 1: Check formatting**

Run: `dart format --output=none --set-exit-if-changed lib/shared/widgets/lyrics lib/features/player/player_page.dart lib/features/player/lyrics_overlay.dart test/shared/widgets/lyrics test/features/player/interactive_lyrics_integration_test.dart`

Expected: exit code 0.

**Step 2: Run static analysis**

Run: `flutter analyze`

Expected: `No issues found!`

**Step 3: Run focused regression tests**

Run: `flutter test test/data/services/lyrics_service_test.dart test/shared/widgets/lyrics test/features/player/interactive_lyrics_integration_test.dart test/shared/widgets/player test/shared/widgets/mini_player_layout_test.dart`

Expected: all tests PASS.

**Step 4: Run the complete suite**

Run: `flutter test`

Expected: all tests PASS without uncaught timers, animations, or exceptions.

**Step 5: Review scope**

Run these commands separately:

```bash
git status --short
git diff --check
git diff --stat
git diff
```

Confirm no server, API, generated, lock, or unrelated plan file changed; both
players use the shared view; and no fixed `currentLyricIdx * 48.0` logic remains.

If no correction was required, do not create an empty commit.

## Completion Evidence

Report implementation, focused tests, static analysis, and full-suite results
separately. Device touch behavior, desktop wheel/trackpad behavior, deployment,
and distribution remain unproven unless explicitly performed.
