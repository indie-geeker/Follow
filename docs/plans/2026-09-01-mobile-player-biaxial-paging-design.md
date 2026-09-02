# Mobile Player Biaxial Paging Design

## Goal

Refine the mobile player so record swipes behave like a two-axis pager, the
folded queue follows the intended right-hand orbit without layout jitter, and
mobile track taps consistently open the full player.

## Approved interaction model

- The record is one gesture surface with dominant-axis locking.
- Horizontal paging keeps the existing behavior: left reveals lyrics and right
  reveals the folded queue.
- Vertical paging previews the adjacent record while dragging. Up reveals the
  next record from below; down reveals the previous record from above.
- Vertical track changes are confirmed only when the pointer is released and
  distance or velocity passes the existing paging threshold. A short drag
  returns to the current record.
- One pointer gesture changes at most one track.
- The playlist gallery remains owned by the top pull handle. The exposed folded
  queue owns vertical scrolling only in its own hit region.

## Record paging architecture

Use a custom biaxial pager rather than nesting horizontal and vertical
`PageView` widgets. `PlayerCoverArt` keeps the single pan recognizer and locks to
one axis after the existing movement threshold, preventing diagonal gestures
from driving two transitions.

For a vertical drag, the record viewport paints the previous, current, and next
record layers. The current layer follows the drag while the matching neighbor
follows from the opposite edge of the clipped record viewport. The viewport
clips the transition so no record covers the title, progress bar, or controls.
Playback changes only after release; cancellation animates back to the current
record.

The previewed neighbor must use the same order as playback. Extract one pure
adjacent-index resolver shared by `playNext`, `playPrevious`, and `PlayerPage`,
including sequence wrap-around, shuffle order, and single-repeat behavior.

## Folded queue corrections

The current orbit function makes the centered cover the farthest-right point,
so a cover moving away from center travels left. Invert the radial progress:
the centered cover begins at the left side of the local orbit and moves right
as its distance from the vertical center increases.

Each queue item reserves a fixed vertical layout:

- 64dp circular cover target;
- 4dp gap;
- fixed 20dp title slot centered under the cover.

The title node always remains in layout. Pointer-held state changes only its
opacity and semantics, preventing geometry changes when the title appears or
disappears.

## Mobile track-tap navigation

Add one shared navigation helper using the existing 800dp adaptive-navigation
breakpoint. On compact layouts, a single-track tap starts the selected queue and
pushes the root `PlayerRoute`. On desktop layouts it starts playback without
opening the full player.

Apply it to:

- `SmartTrackTile` (home, library, playlist, artist, and album lists);
- full search results;
- the library search overlay;
- downloaded-track rows.

Do not change Play All actions, queue selection inside the player, or desktop
player-bar behavior.

## Gesture conflict rules

- The record recognizer locks to horizontal or vertical once per pointer.
- Lyrics owns vertical lyric scrolling only while the lyrics surface is active.
- The folded queue owns vertical scrolling only in its exposed hit region.
- The top playlist pull handle remains a separate vertical region.
- Horizontal paging stays away from screen-edge system gestures because the
  record interaction region is centered.
- Reduced-motion mode keeps state changes but removes nonessential motion.

## Verification

Widget and integration tests must prove:

- a two-track queue moves the first cover right when it is dragged upward;
- the title sits below the cover in a fixed-height slot without layout shift;
- vertical record paging previews the correct neighbor and calls playback only
  after release;
- short and diagonal gestures do not change tracks or activate two axes;
- shuffle and repeat previews match the actual playback resolver;
- all compact single-track entry points call the player navigation helper while
  desktop and Play All flows do not;
- existing lyrics, queue reveal, playlist pull, reduced-motion, accessibility,
  and touch-target tests continue to pass.

## Workspace boundary

The checkout contains unrelated server and enhanced-lyrics changes. Modify only
the named Flutter player, navigation, entry-point, test, and plan files. Do not
reset, clean, broadly stage, commit, push, deploy, or touch production.
