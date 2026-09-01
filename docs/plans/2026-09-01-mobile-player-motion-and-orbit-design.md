# Mobile Player Motion and Orbit Design

**Date:** 2026-09-01

## Goal

Polish the direct-manipulation mobile player with a clearer playlist gallery,
an orbiting snap-to-play queue, slow playback rotation, and bounded vertical
record gestures without changing the existing record/lyrics pager model.

## Playlist Gallery

The playlist gallery remains a real page above the translated player. It uses
the active theme's surface and primary colors for a subtle gradient and ambient
glow, while the horizontally stacked record cards remain the visual focus.

- Previous and next arrow buttons page the gallery with the same controller and
  animation as a horizontal swipe. There is no instructional swipe text.
- Only the centered front card shows an overlaid play button. Pressing it starts
  that playlist and closes the gallery.
- While the gallery is open, any tap on the gallery or the displaced player
  closes it. A drag remains a drag and does not become a dismissal tap.
- The existing explicit up-arrow close affordance is unnecessary once the
  whole open surface dismisses on tap.

## Orbiting Track Queue

The revealed queue has exactly the same vertical extent as the main record.
It uses a fixed-extent scroll controller and starts with the current track at
the record's vertical center. Each visible cover is positioned from its live
distance to the scroll center:

- the centered cover has zero vertical error and the largest scale;
- covers above and below move horizontally along a two-dimensional arc that
  visually wraps around the left edge of the main record;
- distant covers shrink and fade slightly while retaining usable touch targets;
- scrolling ends with the nearest item snapped to center;
- settling automatically plays the centered track;
- tapping a cover animates it to center and then plays it.

While a finger is actively scrolling, the title of the item crossing the
center line appears beside that item in a compact high-contrast label. The
label disappears when the finger lifts; playback begins only after the list
has settled, not repeatedly while it moves.

## Record Rotation

The vinyl visual rotates slowly only while audio is playing. One revolution
takes approximately 24 seconds. Pausing preserves the current angle, resuming
continues from that angle, and an active record drag temporarily pauses the
rotation. Reduced-motion mode disables rotation without changing playback or
gesture behavior.

Only the record artwork rotates. Gesture hit testing, parent page transforms,
shadows, and the queue remain stable.

## Vertical Gesture Boundary

The vertical record translation is clamped to the available visual-surface
inset minus a safety gap, with an additional conservative cap. This prevents
the record from entering the title and controls regions. Gesture completion is
still calculated from the unbounded raw movement and velocity, so a small
visual range does not make previous/next gestures harder to trigger.

## Accessibility and Motion

Arrow buttons and play buttons have tooltips and at least 48dp targets. The
queue exposes selected semantics for the centered/current track. Decorative
glow, rotation, scaling, and animated paging respect reduced-motion settings.
Blank-surface dismissal does not remove system-back or playlist-selection close
behavior.

## Verification

Widget tests prove arrow paging, centered-only play action, tap dismissal,
initial queue centering, live arc transforms, drag-only title visibility,
settle-to-play behavior, playback rotation, pause preservation, reduced-motion
behavior, and bounded vertical visual movement with raw-distance completion.
Then run full Flutter analysis, tests, and an Android debug build.
