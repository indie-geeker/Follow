# Mobile Vinyl Assets and Tonearm Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Keep the supplied tonearm centered and correctly seated on the vinyl, show compact queue titles for up to eight characters, and make paused-state track switches release their busy state as soon as playback starts.

**Architecture:** Keep `PlayerCoverArt` as the owner of record presentation and derive the tonearm's left position from the record center, tonearm width, and source pivot. Keep playback visual state tied to `isPlaying`. Compact only the folded queue's visible title while retaining the full semantic label. In `AudioPlayerService`, observe the long-lived `AudioPlayer.play()` Future for errors without awaiting playback completion, so queue navigation completes after startup.

**Tech Stack:** Flutter, Dart, Flutter widget tests, bundled PNG assets

---

### Task 1: Specify the asset-backed record composition

**Files:**
- Modify: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Create: `follow/assets/images/music-circle.png`

**Step 1: Write the failing widget test**

Add stable keys for the cover layer and edge image. Pump a `PlayerCoverArt` with
a known size and assert that:

```dart
expect(find.byKey(vinylCoverLayerKey), findsOneWidget);
expect(find.byKey(vinylEdgeAssetKey), findsOneWidget);
expect(
  tester.widget<Image>(find.byKey(vinylEdgeAssetKey)).image,
  isA<AssetImage>().having(
    (image) => image.assetName,
    'assetName',
    'assets/images/music-circle.png',
  ),
);
expect(
  tester.getSize(find.byKey(vinylCoverLayerKey)).width,
  closeTo(280 * 0.69, 0.1),
);
```

Inspect the record `Stack` children and assert that the cover precedes the edge
and the spindle follows it. Remove the old expectation that painted grooves and
a large center label define the visual.

**Step 2: Run the focused test to verify RED**

Run:

```bash
cd follow
fvm flutter test test/shared/widgets/player/player_cover_art_test.dart \
  --plain-name 'composes the track cover inside the supplied vinyl edge'
```

Expected: FAIL because the new keys and asset-backed composition do not exist.

**Step 3: Copy the vinyl-edge asset**

Copy `/Users/wen/Downloads/music-circle.png` byte-for-byte to
`follow/assets/images/music-circle.png`. The existing `assets/images/` pubspec
entry already bundles it, so do not add a second asset declaration.

**Step 4: Implement the minimal record layers**

In `_buildRecordPage`, replace the painted treatment with a `Stack` equivalent
to:

```dart
Stack(
  fit: StackFit.expand,
  children: [
    Center(
      child: SizedBox.square(
        key: vinylCoverLayerKey,
        dimension: widget.size * 0.69,
        child: ClipOval(
          child: TrackCoverImage(track: track, size: widget.size * 0.69),
        ),
      ),
    ),
    Image.asset(
      'assets/images/music-circle.png',
      key: isCurrent ? vinylEdgeAssetKey : null,
      fit: BoxFit.contain,
    ),
    Center(child: /* existing small spindle */),
  ],
)
```

Use current-only keys where adjacent record pages would otherwise create
duplicates. Delete `_VinylGroovePainter` when it is no longer referenced.

**Step 5: Run the focused test to verify GREEN**

Run the command from Step 2. Expected: PASS.

### Task 2: Specify and implement the playback tonearm

**Files:**
- Modify: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`
- Create: `follow/assets/images/play-bar.png`

**Step 1: Write failing tonearm state tests**

Add stable keys for the positioned tonearm, its `AnimatedRotation`, and its
asset image. Assert the supplied image path, decorative behavior, and geometry:

```dart
final paused = tester.widget<AnimatedRotation>(
  find.byKey(vinylTonearmRotationKey),
);
expect(paused.turns, 0);
expect(paused.duration, const Duration(milliseconds: 350));

await pumpCover(tester, isPlaying: true);
final playing = tester.widget<AnimatedRotation>(
  find.byKey(vinylTonearmRotationKey),
);
expect(playing.turns, closeTo(1 / 16, 0.0001));
```

Also assert that `isBusy: true` returns the arm to rest and a disabled-animation
`MediaQuery` sets the transition duration to zero.

**Step 2: Run the focused tonearm tests to verify RED**

Run:

```bash
cd follow
fvm flutter test test/shared/widgets/player/player_cover_art_test.dart \
  --plain-name 'tonearm moves from rest to the vinyl edge while playing'
```

Expected: FAIL because no tonearm widget or keys exist.

**Step 3: Copy the tonearm asset**

Copy `/Users/wen/Downloads/play-bar.png` byte-for-byte to
`follow/assets/images/play-bar.png`.

**Step 4: Implement the minimal independent tonearm**

Change the `AnimatedContainer` child to an unclipped `Stack` with the existing
record-page `ClipRect` as its first child and one decorative positioned tonearm
as its second child. Scale and anchor it from `widget.size`:

```dart
Positioned(
  key: vinylTonearmKey,
  left: widget.size * 0.57,
  top: -widget.size * 0.28,
  width: widget.size * 0.56,
  height: widget.size * 0.84,
  child: IgnorePointer(
    child: ExcludeSemantics(
      child: AnimatedRotation(
        key: vinylTonearmRotationKey,
        turns: widget.isPlaying && !widget.isBusy ? 1 / 16 : 0,
        alignment: const Alignment(-0.78, -0.86),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        child: Image.asset(
          'assets/images/play-bar.png',
          key: vinylTonearmAssetKey,
          fit: BoxFit.contain,
        ),
      ),
    ),
  ),
)
```

Keep the tonearm outside the `RotationTransition` and vertical page transforms.
Give it both width and height constraints so its layout does not temporarily
collapse before the bundled PNG has decoded.

**Step 5: Run tonearm tests to verify GREEN**

Run the command from Step 2, then run all tonearm-related cases in the same test
file. Expected: PASS.

### Task 3: Protect existing record behavior

**Files:**
- Modify: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`

**Step 1: Run the complete cover suite**

Run:

```bash
cd follow
fvm flutter test test/shared/widgets/player/player_cover_art_test.dart
```

Expected: all gesture paging, playback rotation, pause preservation, busy-state,
and reduced-motion tests pass.

**Step 2: Run the mobile player integration suite**

Run:

```bash
cd follow
fvm flutter test test/features/player/interactive_lyrics_integration_test.dart
```

Expected: the current queue, lyrics pager, track-change, and layout tests pass.

**Step 3: Format and analyze scoped files**

Run:

```bash
cd follow
dart format lib/shared/widgets/player/player_cover_art.dart \
  test/shared/widgets/player/player_cover_art_test.dart
fvm flutter analyze lib/shared/widgets/player/player_cover_art.dart \
  test/shared/widgets/player/player_cover_art_test.dart
```

Expected: formatting produces no unexpected diff and analysis reports no
issues.

### Task 4: Verify the Flutter application

**Files:**
- Verify: `follow/`

**Step 1: Run the complete Flutter test suite**

```bash
cd follow
fvm flutter test
```

Expected: zero failures.

**Step 2: Build Android debug**

```bash
cd follow
fvm flutter build apk --debug
```

Expected: exit code 0 and a debug APK path in the output.

**Step 3: Review the scoped diff**

```bash
git diff --check -- \
  follow/assets/images/music-circle.png \
  follow/assets/images/play-bar.png \
  follow/lib/shared/widgets/player/player_cover_art.dart \
  follow/test/shared/widgets/player/player_cover_art_test.dart \
  docs/plans/2026-09-01-mobile-vinyl-assets-and-tonearm-design.md \
  docs/plans/2026-09-01-mobile-vinyl-assets-and-tonearm.md
git status --short
```

Expected: no whitespace errors; unrelated pre-existing changes remain untouched.
Do not stage, commit, push, or deploy unless explicitly requested.

### Task 5: Lock the refined tonearm geometry and playback state

**Files:**
- Modify: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`

**Step 1: Write failing geometry and state tests**

At a 280 logical-pixel record size, assert that the tonearm is 140 by 210,
that its base pivot resolves to X=140 in the record coordinate space, that
paused/stopped uses `-1 / 36` turns, and that playing uses `0` turns. Assert
that `isPlaying: true, isBusy: true` remains at the playing angle.

**Step 2: Run the focused test to verify RED**

```bash
cd follow
fvm flutter test --no-pub \
  test/shared/widgets/player/player_cover_art_test.dart \
  --plain-name 'tonearm base stays centered and follows playback state'
```

Expected: FAIL against the old 156.8 by 235.2 geometry, offset base, and
0-to-1/16-turn state mapping.

**Step 3: Implement the minimal responsive geometry**

Use a width factor of `0.50`, preserve the source image's 2:3 aspect ratio,
derive `left` so `left + width * pivotFractionX == size / 2`, and map rest to
`-1 / 36` turns and play to `0`. Do not include `isBusy` in the tonearm angle.

**Step 4: Run the focused and complete cover tests**

Run the Step 2 command, then:

```bash
cd follow
fvm flutter test --no-pub test/shared/widgets/player/player_cover_art_test.dart
```

Expected: PASS with all existing gesture and rotation coverage intact.

### Task 6: Make playback startup non-blocking

**Files:**
- Create: `follow/test/data/providers/audio_playback_start_test.dart`
- Modify: `follow/lib/data/providers/audio_provider.dart`

**Step 1: Write failing playback-start tests**

Specify a helper that invokes a supplied playback callback, returns while its
Future is still pending, and forwards a later asynchronous error exactly once
to an error callback.

**Step 2: Run the focused test to verify RED**

```bash
cd follow
fvm flutter test --no-pub \
  test/data/providers/audio_playback_start_test.dart
```

Expected: FAIL because the playback-start helper does not exist.

**Step 3: Implement and use the minimal helper**

Start the playback Future synchronously, attach a handled success/error branch,
and return without awaiting playback completion. In `playTrack`, await only
this startup boundary after publishing the current track, then keep the
existing non-blocking history recording and playback failure reporting.

**Step 4: Run focused provider and player integration tests**

```bash
cd follow
fvm flutter test --no-pub \
  test/data/providers/audio_playback_start_test.dart \
  test/data/providers/audio_queue_navigation_test.dart \
  test/features/player/interactive_lyrics_integration_test.dart
```

Expected: PASS; previous/next gestures, record state, and the startup Future
contract remain covered.

### Task 7: Verify the refined feature

**Files:**
- Verify: `follow/`

**Step 1: Format and analyze without dependency resolution**

```bash
cd follow
dart format lib/data/providers/audio_provider.dart \
  lib/shared/widgets/player/player_cover_art.dart \
  test/data/providers/audio_playback_start_test.dart \
  test/shared/widgets/player/player_cover_art_test.dart
fvm flutter analyze --no-pub
```

Expected: no formatting errors and `No issues found!`.

**Step 2: Run the full Flutter suite**

```bash
cd follow
fvm flutter test --no-pub
```

Expected: zero failures.

**Step 3: Build and review scope**

```bash
cd follow
fvm flutter build apk --debug --no-pub
git diff --check -- \
  lib/data/providers/audio_provider.dart \
  lib/shared/widgets/player/player_cover_art.dart \
  test/data/providers/audio_playback_start_test.dart \
  test/shared/widgets/player/player_cover_art_test.dart
git status --short
```

Expected: build exit 0, no scoped whitespace errors, and no tool-induced lock
or Gradle configuration changes. Do not stage, commit, push, or deploy.

### Task 8: Refine the playback-to-pause angle span

**Files:**
- Modify: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`

**Step 1: Change the widget expectations first**

Keep the existing base-center and size assertions. Change only the state angle
expectations to `-25 / 360` turns while paused and `-3 / 360` turns while
playing or playing-busy. This fixes the approved 22-degree span in a regression
test without changing the pivot geometry.

**Step 2: Run the focused test to verify RED**

```bash
cd follow
fvm flutter test --no-pub \
  test/shared/widgets/player/player_cover_art_test.dart \
  --plain-name 'tonearm base stays centered and follows playback state'
```

Expected: FAIL because the implementation still uses paused `-23°` and playing
`-3°`.

**Step 3: Implement the exact approved angles**

Define separate constants for the paused and playing turns:

```dart
static const _tonearmRestingTurns = -25 / 360;
static const _tonearmPlayingTurns = -3 / 360;
```

Select between them using `isPlaying`. Do not change size, pivot, left/top
position, animation duration, busy behavior, or reduced-motion behavior.

**Step 4: Run focused and complete verification**

```bash
cd follow
fvm flutter test --no-pub \
  test/shared/widgets/player/player_cover_art_test.dart
fvm flutter analyze --no-pub
fvm flutter test --no-pub
fvm flutter build apk --debug --no-pub
```

Expected: the focused suite, complete test suite, analysis, and Android debug
build all pass. Generate temporary paused/playing screenshots to verify the
head positions visually, then remove those temporary files. Restore only any
tool-induced lock or Gradle migration changes. Do not commit, push, or deploy.

### Task 9: Show eight-character folded queue titles

**Files:**
- Modify: `follow/test/shared/widgets/player/folded_track_queue_test.dart`
- Modify: `follow/lib/shared/widgets/player/folded_track_queue.dart`

**Step 1: Add boundary widget tests first**

While holding the centered folded-queue item, verify that an eight-character
title remains unchanged and a nine-character title renders as its first eight
user-visible characters plus `…`. Assert that the title slot is 112 logical
pixels wide and that the cover semantics still contain the complete title.

**Step 2: Run the focused tests to verify RED**

```bash
cd follow
fvm flutter test --no-pub \
  test/shared/widgets/player/folded_track_queue_test.dart
```

Expected: FAIL because the current widget passes the complete title to a
64-logical-pixel text slot and relies only on width-based overflow.

**Step 3: Implement the compact display title**

Use Dart's user-visible `characters` view, which Flutter exports, to preserve
grapheme clusters. Return the original title at eight characters or fewer;
otherwise join the first eight characters and append one ellipsis. Use this
value only for the visible folded-queue label. Keep the full title in the
existing semantic label, retain one-line overflow as a defensive fallback, and
increase only the title slot width to 112.

**Step 4: Verify the focused and full Flutter checks**

```bash
cd follow
dart format \
  lib/shared/widgets/player/folded_track_queue.dart \
  lib/shared/widgets/player/player_cover_art.dart \
  test/shared/widgets/player/folded_track_queue_test.dart \
  test/shared/widgets/player/player_cover_art_test.dart
fvm flutter test --no-pub \
  test/shared/widgets/player/folded_track_queue_test.dart \
  test/shared/widgets/player/player_cover_art_test.dart
fvm flutter analyze --no-pub
fvm flutter test --no-pub
fvm flutter build apk --debug --no-pub
```

Expected: all focused and complete checks pass. Review only the four scoped
source/test files plus these existing plan documents. Do not commit, push, or
deploy.
