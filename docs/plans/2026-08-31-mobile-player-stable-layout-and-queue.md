# Mobile Player Stable Layout and Queue Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the mobile player stable across cover/lyrics paging, enlarge the shared lyric viewport, center the transport controls, and open the active play queue from a right-side button.

**Architecture:** Replace page-dependent flex consumption with one flexible shared visual region plus a fixed-height information slot. Render transport controls in the center layer of a full-width stack, with mode and queue actions aligned independently at the sides. Keep queue state and behavior in the existing providers and `PlayQueueSheet`.

**Tech Stack:** Flutter, Dart, Riverpod, Flutter widget tests

---

> Workspace constraint: preserve all existing dirty-tree changes. Do not stage,
> commit, push, deploy, or modify unrelated lyric timing/parser work.

### Task 1: Specify the stable mobile player layout

**Files:**
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Extend the player test fixture**

Allow `_pumpPlayerPage` to receive a `Track` and override
`playQueueProvider` with a two-track active queue. Continue setting the current
track through `currentTrackProvider.notifier` so the page exercises its real
provider flow.

```dart
Future<ProviderContainer> _pumpPlayerPage(
  WidgetTester tester, {
  required AsyncValue<List<LyricLine>> lyrics,
  Track track = _firstTrack,
}) async {
  // Existing overrides...
  playQueueProvider.overrideWithValue([track, _secondTrack]),
  // ...
  container.read(currentTrackProvider.notifier).setTrack(track);
}
```

**Step 2: Write the failing stability test**

Use a two-line title so the current variable title block differs materially
from the lyrics page's 60-pixel spacer. Assert that the shared `PageView` is
taller than the old `390 - 40` viewport, that the indicator begins at least 12
pixels below it, and that the slider's vertical position is unchanged after
paging.

```dart
testWidgets('mobile player keeps lower layout stable and enlarges lyrics area',
    (tester) async {
  const longTitleTrack = Track(
    id: 'long-title',
    title: 'A deliberately long mobile player title that wraps onto two lines',
    durationSeconds: 180,
    artist: Artist(id: 'artist-1', name: 'Artist'),
  );
  await _pumpPlayerPage(
    tester,
    lyrics: AsyncData(_lyrics),
    track: longTitleTrack,
  );

  final pageView = find.byType(PageView);
  final slider = find.byType(Slider);
  expect(tester.getSize(pageView).height, greaterThan(350));
  expect(
    tester.getTopLeft(find.byType(PageIndicatorDot).first).dy -
        tester.getBottomLeft(pageView).dy,
    greaterThanOrEqualTo(12),
  );
  final coverSliderY = tester.getTopLeft(slider).dy;

  await _showLyricsPage(tester);

  expect(tester.getTopLeft(slider).dy, closeTo(coverSliderY, 0.01));
  expect(tester.takeException(), isNull);
});
```

**Step 3: Run the test to verify RED**

Run:

```bash
cd follow
fvm flutter test test/features/player/interactive_lyrics_integration_test.dart \
  --plain-name 'mobile player keeps lower layout stable and enlarges lyrics area'
```

Expected: FAIL because the old viewport is exactly 350 pixels and the lower
layout still depends on page-specific content height.

### Task 2: Implement the stable responsive visual region

**Files:**
- Modify: `follow/lib/features/player/player_page.dart:226-399`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Replace page-dependent spacers with a flexible upper region**

Inside the existing `SafeArea`, make the visual region the only expanding part:

```dart
Column(
  children: [
    const SizedBox(height: 8),
    Expanded(
      child: Column(
        children: [
          Expanded(child: PageView(/* existing children */)),
          const SizedBox(height: 16),
          Row(/* existing PageIndicatorDot children */),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: _currentPage == 0
                ? Padding(/* existing title and artist */)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    // Existing progress, volume, controls, and bottom spacing.
  ],
)
```

Do not resize `PlayerCoverArt`; its existing 280-pixel preferred size remains
centered and can be constrained naturally on compact devices. Do not change
`InteractiveLyricsView` behavior or lyric timing inputs.

**Step 2: Run the stability test to verify GREEN**

Run the same focused command from Task 1.

Expected: PASS with no overflow exception.

**Step 3: Run existing mobile lyric integration tests**

Run:

```bash
cd follow
fvm flutter test test/features/player/interactive_lyrics_integration_test.dart
```

Expected: all tests PASS, including horizontal paging, vertical lyric browsing,
track replacement, and loading/empty/error states.

### Task 3: Specify independent side actions and centered transport controls

**Files:**
- Modify: `follow/test/shared/widgets/player/player_main_controls_test.dart`
- Test: `follow/test/shared/widgets/player/player_main_controls_test.dart`

**Step 1: Add a queue callback to the fixture**

Track `queueCalls`, reset it in `setUp`, and pass `onShowQueue` to
`PlayerMainControls`.

```dart
late int queueCalls;

setUp(() {
  queueCalls = 0;
});

PlayerMainControls(
  // Existing callbacks...
  onShowQueue: () => queueCalls++,
)
```

**Step 2: Write the failing geometry and action test**

```dart
testWidgets('transport stays centered between mode and queue actions',
    (tester) async {
  await pumpControls(tester);

  final controlsCenter =
      tester.getCenter(find.byType(PlayerMainControls)).dx;
  final previousX = tester.getCenter(find.byTooltip('上一首')).dx;
  final playX = tester.getCenter(find.byTooltip('播放')).dx;
  final nextX = tester.getCenter(find.byTooltip('下一首')).dx;
  final modeX = tester.getCenter(find.byTooltip('播放模式：顺序播放')).dx;
  final queueX = tester.getCenter(find.byTooltip('当前播放队列')).dx;

  expect(playX, closeTo(controlsCenter, 0.01));
  expect((previousX + nextX) / 2, closeTo(controlsCenter, 0.01));
  expect(modeX, lessThan(previousX));
  expect(queueX, greaterThan(nextX));

  await tester.tap(find.byTooltip('当前播放队列'));
  expect(queueCalls, 1);
});
```

Also include `当前播放队列` in the existing minimum 48-pixel touch-target
assertions.

**Step 3: Run the test to verify RED**

Run:

```bash
cd follow
fvm flutter test test/shared/widgets/player/player_main_controls_test.dart
```

Expected: compilation/test failure because `onShowQueue` and the queue action do
not exist, and the current four-item row offsets the transport group.

### Task 4: Implement the centered control stack

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_main_controls.dart`
- Test: `follow/test/shared/widgets/player/player_main_controls_test.dart`

**Step 1: Add the callback contract**

```dart
final VoidCallback onShowQueue;

const PlayerMainControls({
  // Existing fields...
  required this.onShowQueue,
});
```

**Step 2: Replace the row with a full-width stack**

Use 16-pixel horizontal padding and a 72-pixel high stack. Keep 12-pixel gaps
inside the centered transport row so two 48-pixel side targets do not overlap
the transport group on a 320-pixel device.

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: SizedBox(
    height: 72,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PlayerControlButton(/* existing mode action */),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerControlButton(/* previous */),
            const SizedBox(width: 12),
            // Existing 72-pixel play/pause button.
            const SizedBox(width: 12),
            PlayerControlButton(/* next */),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: PlayerControlButton(
            icon: Icons.queue_music_rounded,
            size: 24,
            tooltip: '当前播放队列',
            onPressed: onShowQueue,
          ),
        ),
      ],
    ),
  ),
)
```

**Step 3: Run the controls tests to verify GREEN**

Run the same command from Task 3.

Expected: all controls tests PASS and every action remains at least 48 pixels.

### Task 5: Open the active queue from PlayerPage

**Files:**
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Modify: `follow/lib/features/player/player_page.dart:1-90,382-394`
- Reuse: `follow/lib/shared/widgets/play_queue_sheet.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Write the failing integration test**

Import `PlayQueueSheet`, tap the new tooltip, and assert that the active queue is
shown in a modal.

```dart
testWidgets('mobile player queue action opens the active playback queue',
    (tester) async {
  await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

  await tester.tap(find.byTooltip('当前播放队列'));
  await tester.pumpAndSettle();

  expect(find.byType(PlayQueueSheet), findsOneWidget);
  expect(find.text('播放队列 (2)'), findsOneWidget);
  expect(find.text('First track'), findsOneWidget);
  expect(find.text('Second track'), findsOneWidget);
});
```

**Step 2: Run the integration test to verify RED**

Run:

```bash
cd follow
fvm flutter test test/features/player/interactive_lyrics_integration_test.dart \
  --plain-name 'mobile player queue action opens the active playback queue'
```

Expected: FAIL because `PlayerPage` does not yet pass a queue-sheet callback.

**Step 3: Add the modal presentation**

Import `PlayQueueSheet` and add:

```dart
void _showPlayQueue(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PlayQueueSheet(),
  );
}
```

Pass `onShowQueue: () => _showPlayQueue(context)` to `PlayerMainControls`.

**Step 4: Run the integration test to verify GREEN**

Run the same focused command from Step 2.

Expected: PASS and the existing sheet lists both queue tracks.

### Task 6: Format and verify the complete scoped change

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/lib/shared/widgets/player/player_main_controls.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Modify: `follow/test/shared/widgets/player/player_main_controls_test.dart`

**Step 1: Format only scoped Dart files**

Run:

```bash
cd follow
fvm dart format \
  lib/features/player/player_page.dart \
  lib/shared/widgets/player/player_main_controls.dart \
  test/features/player/interactive_lyrics_integration_test.dart \
  test/shared/widgets/player/player_main_controls_test.dart
```

Expected: exit 0.

**Step 2: Run focused player tests**

Run:

```bash
cd follow
fvm flutter test \
  test/features/player/interactive_lyrics_integration_test.dart \
  test/shared/widgets/player/player_main_controls_test.dart \
  test/shared/widgets/play_queue_sheet_test.dart
```

Expected: all tests PASS.

**Step 3: Run static analysis for the touched implementation and tests**

Run:

```bash
cd follow
fvm flutter analyze \
  lib/features/player/player_page.dart \
  lib/shared/widgets/player/player_main_controls.dart \
  test/features/player/interactive_lyrics_integration_test.dart \
  test/shared/widgets/player/player_main_controls_test.dart
```

Expected: no issues found.

**Step 4: Inspect workspace effects**

Run:

```bash
git status --short
git diff --check -- \
  follow/lib/features/player/player_page.dart \
  follow/lib/shared/widgets/player/player_main_controls.dart \
  follow/test/features/player/interactive_lyrics_integration_test.dart \
  follow/test/shared/widgets/player/player_main_controls_test.dart \
  docs/plans/2026-08-31-mobile-player-stable-layout-and-queue-design.md \
  docs/plans/2026-08-31-mobile-player-stable-layout-and-queue.md
git diff --exit-code -- follow/pubspec.lock
```

Expected: only intended scoped changes plus the user's pre-existing dirty files;
no whitespace errors and no test-induced lock-file mutation.
