# Mobile Vinyl Assets and Tonearm Design

**Date:** 2026-09-01

## Goal

Replace the mobile player's painted vinyl treatment with the supplied vinyl-edge
asset, reveal the current track cover inside its transparent center, and add the
supplied tonearm asset with playback-driven positioning.

## Scope

This change is limited to the Flutter mobile player's vinyl presentation, the
compact folded queue title presentation, and the completion semantics of the
local playback-start operation. It does not change remote playback APIs, queue
ordering, vertical track paging, the record/lyrics horizontal pager, desktop
layouts, or server behavior.

The source assets are copied without modification:

- `/Users/wen/Downloads/music-circle.png`
- `/Users/wen/Downloads/play-bar.png`

They become bundled Flutter assets under `follow/assets/images/`.

## Record Composition

The record remains a responsive square whose side is `PlayerCoverArt.size`.
Each record page uses three centered layers:

1. The track cover is clipped to a circle sized slightly larger than the
   transparent center of `music-circle.png`, so it sits behind the edge without
   leaving an antialiasing gap.
2. `music-circle.png` fills the record square and supplies the visible black
   vinyl edge and grooves.
3. The existing small spindle remains centered above both layers.

The current painted groove overlay, dark cover veil, and large black center
label are removed because they would obscure the supplied edge and the cover.
The full record composition continues to rotate with the existing 24-second
playback animation.

## Tonearm Geometry and State

The tonearm is a decorative sibling of the vertically paged records, not a
child of the rotating record. Its base is anchored above the record and the
base center is always horizontally aligned with the record center. The
position is derived from the tonearm width and source-image pivot instead of a
separate magic left offset, so responsive record sizes preserve the alignment.
The tonearm is approximately ten percent smaller than the first version. The
transform pivot matches the center of the circular base in the source image.

- Paused or stopped: the arm rests 25 degrees counterclockwise from the source
  image's natural angle, with the magnetic head outside the record (reference
  line 1).
- Playing: the arm rests 3 degrees counterclockwise from the source image's
  natural angle, where the magnetic head remains on the black outer vinyl area
  rather than the cover.
- The playback transition therefore spans exactly 22 degrees. The top base,
  tonearm size, and transform pivot remain unchanged.
- A transient gesture/setup busy state does not override a true playing state;
  the tonearm represents playback, while gesture blocking remains independent.
- Transition: about 350 milliseconds with an ease-in-out curve.
- Reduced motion: the position changes immediately without interpolation.

The tonearm does not spin with the cover and does not participate in vertical
previous/next record paging. It remains attached to the overall record surface
when that surface moves horizontally to reveal lyrics or the queue.

## Folded Queue Titles

Only the compact folded track queue shown beside the record changes. While a
centered item is held, titles up to eight user-visible characters are shown in
full. Longer titles show their first eight characters followed by a single
ellipsis. The title slot expands from 64 to 112 logical pixels so eight CJK
characters and the ellipsis fit at the normal label size without changing the
64-pixel cover or its touch target. The cover's semantics continue to announce
the complete, untruncated title.

## Track-Switch Playback Lifecycle

`just_audio` completes the Future returned by `play()` when playback later
pauses, stops, or completes. Awaiting that Future in `playTrack` therefore keeps
the player's track-gesture busy state active for the lifetime of the song. The
record stops rotating and the old tonearm rule retracts even though playback is
active.

After the new source has loaded and the current track has been published,
`playTrack` starts `play()` and attaches a deferred error observer without
waiting for the whole playback lifetime. It then records history and returns.
This makes previous/next gestures complete once playback has started, including
when the user switches tracks from a paused state. Source-loading or synchronous
startup failures still use the existing playback-failure state; later playback
Future errors are reported through the same state without becoming unhandled
asynchronous errors.

## Accessibility and Interaction

The existing record semantics and gesture target remain unchanged. The tonearm
is decorative, excluded from semantics, and ignores pointer input so it cannot
block record swipes.

## Verification

Widget tests will verify:

- the supplied edge and tonearm asset paths are rendered;
- the cover is circular, centered, and below the vinyl edge;
- the spindle remains above the cover and edge;
- the tonearm base center is horizontally aligned with the record center;
- the tonearm uses the smaller approved dimensions and base-centered pivot;
- pause/stop and playing map to the approved rest and engaged angles;
- folded queue titles preserve eight characters and add an ellipsis only when
  the source title is longer;
- folded queue cover semantics retain the complete title;
- a busy gesture does not retract the arm when playback is already active;
- reduced-motion mode removes the tonearm transition;
- the existing playback-only record rotation and gesture tests still pass.

A focused playback-start unit test will prove that the start helper returns
while the playback Future is still pending and reports any later Future error.

Run the focused widget tests, Flutter analysis, the complete Flutter test suite,
and an Android debug build. Review only the scoped diff. Do not commit, push, or
clean unrelated working-tree changes without an explicit request.
