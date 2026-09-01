# Mobile Vinyl Gesture Player Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the approved circular vinyl mobile player with a pull-down playlist gallery, vertical track swipes, left-swipe lyrics, and a right-revealed folded queue.

**Architecture:** Keep playback and playlist data in the existing Riverpod layer, adding only an optional queue-source playlist id and explicit playlist/queue selection methods. Split the visual behavior into focused Flutter widgets for the vinyl record, playlist gallery, and folded queue, while `PlayerPage` owns the mutually exclusive cover, lyrics, queue, and gallery states and arbitrates gesture regions.

**Tech Stack:** Flutter 3.41, Dart, Riverpod 3 code generation, Material 3, flutter_test, just_audio.

**Working-tree note:** The checkout already contains user-owned changes in player, lyrics, controls, tests, and server tests. Work directly on the current checkout because the approved feature depends on those modified player files. Do not reset, clean, stage, commit, push, deploy, or modify server files. Review only scoped diffs. The commit steps normally prescribed by the planning skill are intentionally omitted because no commit was authorized.

---

### Task 1: Add playback source and safe queue-selection semantics

**Files:**
- Modify: `follow/lib/data/providers/audio_provider.dart`
- Modify: `follow/lib/shared/widgets/play_queue_sheet.dart`
- Test: `follow/test/data/providers/audio_queue_source_test.dart`
- Test: `follow/test/shared/widgets/play_queue_sheet_test.dart`

**Step 1: Write failing provider tests**

Prove that arbitrary `playAll` clears the queue-source playlist id,
`playPlaylist` sets it and begins at index zero, selecting an existing queue
index preserves it, and removing or clearing queue content clears it. Use a
provider/service seam so state transitions do not open a real audio connection.

**Step 2: Run tests to verify RED**

Run:

```bash
cd follow
fvm flutter test test/data/providers/audio_queue_source_test.dart
```

Expected: FAIL because source state and playlist/queue playback methods do not
exist.

**Step 3: Implement minimum playback state**

Add a keep-alive `CurrentPlaylistId` notifier. Refactor queue setup into a
private helper and expose:

```dart
Future<void> playAll(List<Track> tracks, {int startIndex = 0});
Future<void> playPlaylist(String playlistId, List<Track> tracks);
Future<void> playQueueItemAt(int index);
```

`playAll` clears source, `playPlaylist` sets it, and `playQueueItemAt`
preserves it. Clear source when the queue is cleared or structurally edited.

**Step 4: Update and verify the queue sheet**

Change queue-row selection to `playQueueItemAt(index)`. Regenerate Riverpod
output, then run:

```bash
cd follow
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter test test/data/providers/audio_queue_source_test.dart test/shared/widgets/play_queue_sheet_test.dart
```

Expected: all selected tests PASS.

### Task 2: Render the circular vinyl and classify record gestures

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Test: `follow/test/shared/widgets/player/player_cover_art_test.dart`

**Step 1: Write failing widget tests**

Prove circular geometry, groove and spindle layers, separate up/down/left/right
callbacks, ignored sub-threshold drags, and exactly one callback per completed
gesture.

**Step 2: Run tests to verify RED**

```bash
cd follow
fvm flutter test test/shared/widgets/player/player_cover_art_test.dart
```

Expected: FAIL because the cover is square and has no directional callbacks.

**Step 3: Implement minimum vinyl surface**

Extend `PlayerCoverArt` with optional directional callbacks and a busy flag.
Use circular clipping, concentric borders, center label/hole, semantic labeling,
dominant-axis locking, transform feedback, and distance/velocity resolution on
release.

**Step 4: Verify GREEN**

Run the focused cover test and expect all cases to PASS.

### Task 3: Build the pull-down stacked playlist gallery

**Files:**
- Create: `follow/lib/shared/widgets/player/playlist_gallery_drawer.dart`
- Test: `follow/test/shared/widgets/player/playlist_gallery_drawer_test.dart`

**Step 1: Write failing widget tests**

Prove loading, error, empty, and data states. In the data state prove the
centered playlist is larger than neighbors, horizontal drag changes focus, the
active source is announced, centered selection calls `onSelect` once, and busy
selection blocks duplicate taps.

**Step 2: Run tests to verify RED**

```bash
cd follow
fvm flutter test test/shared/widgets/player/playlist_gallery_drawer_test.dart
```

Expected: FAIL because the gallery widget does not exist.

**Step 3: Implement gallery presentation**

Receive `AsyncValue<List<Playlist>>`, active playlist id, async selection, and
close callbacks. Use `PageController(viewportFraction: 0.58)` and transform
cards by page distance. Render `coverUrl` or a themed record placeholder.

**Step 4: Verify GREEN**

Run the focused gallery test and expect all cases to PASS.

### Task 4: Build the folded queue reveal

**Files:**
- Create: `follow/lib/shared/widgets/player/folded_track_queue.dart`
- Test: `follow/test/shared/widgets/player/folded_track_queue_test.dart`

**Step 1: Write failing widget tests**

Prove the empty state, current-track semantics, progressively scaled neighboring
covers, vertical scrolling, `onSelect(index)`, and a 48dp close action.

**Step 2: Run tests to verify RED**

```bash
cd follow
fvm flutter test test/shared/widgets/player/folded_track_queue_test.dart
```

Expected: FAIL because the folded queue widget does not exist.

**Step 3: Implement folded queue**

Use a vertical list/stack on a left-side arc. Keep the current track visually
dominant and scale/fade neighbors by index distance. The widget remains
read-only except for selecting a playback index.

**Step 4: Verify GREEN**

Run the focused queue test and expect all cases to PASS.

### Task 5: Integrate the mobile player gesture state machine

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/lib/features/home/views/playlist_view.dart`
- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Write failing interaction tests**

Replace obsolete mobile page-dot/PageView assertions and prove:

- no `PageIndicatorDot` is rendered;
- the cover is circular;
- pulling the page-top handle past threshold opens the gallery;
- selecting a playlist calls playlist playback and closes the gallery;
- record up/down calls next/previous exactly once;
- record left shows `InteractiveLyricsView`;
- lyric vertical browsing remains intact and a right gesture returns to record;
- record right reveals the folded queue;
- queue selection calls queue-index playback;
- gallery, lyrics, and queue states are mutually exclusive.

**Step 2: Run integration test to verify RED**

```bash
cd follow
fvm flutter test test/features/player/interactive_lyrics_integration_test.dart
```

Expected: FAIL because `PlayerPage` still uses `PageView`, dots, a square cover,
and bottom-sheet-only queue.

**Step 3: Implement state machine**

Replace the mobile cover/lyrics `PageView` with mutually exclusive cover,
lyrics, and queue layers in a `Stack`. Add a page-top pull handle that does not
overlap the record. Wire record directions to playback and content states. Show
the gallery above a scrim and select through
`playlistDetailProvider(id).future`, then `playPlaylist(id, tracks)`.

Keep progress, volume, mode, previous/play/next, and visible queue alternatives
stable. Make the queue button open the folded queue, not a second interaction
model. Change `PlaylistView` to use `playPlaylist`.

**Step 4: Verify GREEN**

```bash
cd follow
fvm flutter test \
  test/features/player/interactive_lyrics_integration_test.dart \
  test/shared/widgets/player/player_main_controls_test.dart \
  test/shared/widgets/lyrics/interactive_lyrics_view_test.dart
```

Expected: all selected tests PASS.

### Task 6: Run the full quality gate

**Files:**
- Modify only formatting and generated outputs required by scoped Flutter files.

**Step 1: Format scoped files**

Run `fvm dart format` only on changed Dart files and tests.

**Step 2: Analyze**

```bash
cd follow
fvm flutter analyze
```

Expected: exit 0 with no analyzer findings.

**Step 3: Test**

```bash
cd follow
fvm flutter test
```

Expected: all tests PASS.

**Step 4: Build**

```bash
cd follow
fvm flutter build apk --debug
```

Expected: exit 0 and a debug APK path is reported.

**Step 5: Review scope**

```bash
git diff --check
git status --short
git diff -- follow/lib follow/test \
  docs/plans/2026-09-01-mobile-vinyl-gesture-player-design.md \
  docs/plans/2026-09-01-mobile-vinyl-gesture-player.md
```

Confirm no server, production, deployment, unrelated user files, or lock files
were modified by this feature. Report implementation, tests, build, and device
validation separately. Do not claim emulator, device, or driving proof without
running those checks.
