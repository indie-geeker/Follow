# Mobile Player Biaxial Paging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Correct the folded queue motion, add release-confirmed vertical record paging, reserve a stable title slot, and open the player from every compact single-track entry point.

**Architecture:** Keep one axis-locking gesture recognizer on the record and render adjacent record layers inside a clipped vertical viewport. Share one adjacent-queue-index resolver between playback and visual previews, and centralize compact-layout player navigation in a small router helper.

**Tech Stack:** Flutter 3.41.6, Dart, Riverpod, auto_route, Material 3, flutter_test.

---

### Task 1: Correct the orbit and reserve the queue title slot

**Files:**
- Modify: `follow/test/shared/widgets/player/folded_track_queue_test.dart`
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`

**Step 1: Write the failing orbit-direction test**

Pump a two-track queue on track zero, hold the list, drag upward without
releasing, and assert the first cover's horizontal translation increases as it
moves above center.

**Step 2: Write the failing fixed-title-slot test**

Record the centers and list size before and during a held drag. Assert that the
center title is below and horizontally centered with its cover, its slot height
is fixed, and surrounding item geometry does not move when opacity changes.

**Step 3: Verify RED**

Run:

```bash
cd follow
/Users/wen/fvm/versions/3.41.6/bin/flutter test --no-pub \
  test/shared/widgets/player/folded_track_queue_test.dart
```

Expected: the upward-moving first cover travels left and the conditional row
title is not below a fixed slot.

**Step 4: Implement the minimal correction**

Invert the orbit progress so horizontal offset increases with distance from
center. Increase the fixed item extent to contain a 64dp cover, 4dp gap, and
20dp label slot. Replace conditional row insertion with a fixed `SizedBox` and
opacity-only title state.

**Step 5: Verify GREEN**

Run the focused queue test and require all cases to pass.

### Task 2: Share adjacent playback order

**Files:**
- Modify: `follow/test/data/providers/audio_queue_source_test.dart`
- Modify: `follow/lib/data/providers/audio_provider.dart`

**Step 1: Write failing pure resolver tests**

Cover sequence wrap-around, shuffle order in both directions, missing shuffled
indices, and single-repeat returning the current index.

**Step 2: Verify RED**

Run the provider test and confirm the resolver does not exist.

**Step 3: Implement the resolver**

Add one pure adjacent-index function and use it from both `playNext` and
`playPrevious`. Preserve current empty-queue and shuffle fallback behavior.

**Step 4: Verify GREEN**

Run the provider tests and require playback state behavior to remain green.

### Task 3: Add release-confirmed vertical record paging

**Files:**
- Modify: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Modify: `follow/lib/features/player/player_page.dart`

**Step 1: Write failing pager-motion tests**

Pass previous and next tracks to the cover. During an upward drag, assert the
current record follows upward and the next record follows from below. Assert no
swipe callback fires before release.

**Step 2: Write failing settle tests**

Assert a completed upward/downward gesture calls next/previous once after
release, a short drag returns without playback, and a diagonal gesture drives
only the locked axis.

**Step 3: Write the failing playback-order integration test**

Override queue, current index, mode, and shuffle order. Assert the visual
previous/next records match the same adjacent indices that playback will use.

**Step 4: Verify RED**

Run cover and player integration tests and confirm adjacent record layers are
missing while callbacks still depend on the old single-record visual.

**Step 5: Implement the custom vertical pager**

Extend `PlayerCoverArt` with previous/next tracks and stable keys. Within a
clipped record-sized stack, render the current layer and the direction-matching
neighbor. Keep horizontal visual reporting for lyrics/queue, but own vertical
record paging internally. On release, use the existing distance/velocity rule
to confirm or return; never trigger playback from `onPanUpdate`.

**Step 6: Integrate playback order**

In `PlayerPage`, watch current index, play mode, and shuffled indices, resolve
the visual neighbors through the shared resolver, and pass them to the cover.
Keep playlist pull, lyrics paging, queue reveal, rotation, busy-state, and back
behavior unchanged.

**Step 7: Verify GREEN**

Run cover, integration, lyrics, and control tests until all pass.

### Task 4: Open the full player from compact single-track taps

**Files:**
- Create: `follow/lib/router/player_navigation.dart`
- Create: `follow/test/router/player_navigation_test.dart`
- Modify: `follow/lib/shared/widgets/smart_track_tile.dart`
- Modify: `follow/lib/features/search/search_page.dart`
- Modify: `follow/lib/features/library/widgets/library_search_box.dart`
- Modify: `follow/lib/features/downloads/downloads_page.dart`
- Modify: `follow/test/features/downloads/downloaded_track_tile_test.dart`

**Step 1: Write failing breakpoint and entry-point tests**

Prove 799dp opens the root player route and 800dp does not. Add focused widget
or source-guard assertions that each compact single-track entry point invokes
the shared helper after selecting playback, while Play All remains unchanged.

**Step 2: Verify RED**

Run router, download, and relevant source-guard tests; confirm the helper and
calls are absent.

**Step 3: Implement centralized navigation**

Create a helper that reuses `usesDesktopNavigation` and pushes `PlayerRoute`
through the root router only on compact layouts. Call it from `SmartTrackTile`,
search results, library search, and downloaded-track playback. Close the
library search overlay before navigation.

**Step 4: Verify GREEN**

Run the navigation and affected widget tests and require all cases to pass.

### Task 5: Final verification

**Files:**
- Format only the files named above.

**Step 1: Format scoped Dart files**

Run exact Dart 3.41.6 formatting on only the changed Dart sources and tests.

**Step 2: Run focused tests**

Run queue, cover, audio-provider, player integration, lyrics, controls,
navigation, and downloaded-track tests.

**Step 3: Analyze and run the full suite**

Run:

```bash
cd follow
/Users/wen/fvm/versions/3.41.6/bin/flutter analyze --no-pub
/Users/wen/fvm/versions/3.41.6/bin/flutter test --no-pub
```

Require zero analyzer findings and zero test failures.

**Step 4: Build Android debug APK**

Run:

```bash
cd follow
/Users/wen/fvm/versions/3.41.6/bin/flutter build apk --debug --no-pub
```

Capture the artifact path, size, and SHA-256. Confirm the build did not modify
`follow/android/gradle.properties` or `follow/pubspec.lock`.

**Step 5: Review scope**

Run `git diff --check`, inspect only named diffs, and report implementation,
tests/build, commit/push/deploy, and device verification as separate states.
