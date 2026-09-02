# Mobile Folded Queue Dismissal Design

## Goal

Make the folded queue beside the record a short-lived, contextual surface. It
must remain usable for direct queue browsing, but it must get out of the way as
soon as the user operates another part of the player. The persistent current
queue entry point remains the existing bottom sheet.

## Approved interaction model

- Swiping or tapping inside the folded queue keeps the queue open while the
  interaction is active.
- Queue pointer-down cancels any pending auto-close. Once scrolling/snapping and
  any resulting selection have settled, start a fresh two-second auto-close
  timer.
- Any player interaction outside the folded queue closes it immediately. This
  includes record pointer-down, transport and mode controls, progress and volume
  interaction, the playlist pull handle, top app-bar actions, and back.
- Tapping the record closes the queue and toggles play/pause. A drag closes the
  queue and then continues through the existing dominant-axis record gesture.
- The bottom current-queue action closes the folded queue and opens the existing
  `PlayQueueSheet` modal bottom sheet. It must no longer reveal the folded queue.
- Reopening the folded queue centers the current track.

## Dismissal ownership and timer lifecycle

`PlayerPage` owns whether the folded queue is visible and owns its auto-close
timer. The timer is not playback state and must not move into Riverpod.

The queue widget reports three semantic events to `PlayerPage`:

1. interaction started;
2. interaction settled;
3. a queue item was selected.

Interaction start cancels the timer. Interaction settle starts a new two-second
timer after snapping is complete. The timer callback closes the queue only if it
is still open and no queue interaction is active. Closing the queue, leaving the
page, or disposing the page cancels the timer.

All callbacks that operate outside the folded queue route through one dismissal
helper before performing their existing action. Pointer-driven surfaces cancel
the timer and begin dismissal at pointer-down, rather than waiting for a tap or
drag to win the gesture arena.

## Motion

Use the existing queue reveal opacity and record translation as the basis of the
transition. Closing animates over roughly 200-240 ms with `easeOutCubic`:

- queue items fade and recede behind the record;
- the record returns horizontally to center;
- the user's subsequent record drag remains responsive.

Avoid synchronizing the queue list with a vertical record drag. Since record
pointer-down now dismisses the queue, continuous list movement would be barely
visible while adding competing scroll, snap, selection, and playback ownership.
When the queue is opened again, its existing current-track synchronization is
the meaningful continuity cue.

When reduced motion is enabled, state changes happen without nonessential
animation.

## Current queue bottom sheet

Restore the previous full-queue affordance by adding a `PlayerPage` helper that
calls `showModalBottomSheet` and builds `PlayQueueSheet`. The bottom control calls
this helper, not `_showQueue`. The existing sheet remains the management surface
for selecting, removing, and clearing queue items; the folded queue remains a
temporary direct-manipulation preview.

## Record tap and gesture arbitration

`PlayerCoverArt` exposes separate callbacks for pointer interaction start and
tap. Pointer start dismisses the folded queue immediately. Tap toggles
play/pause. Once movement passes the existing axis-lock threshold, the pan
recognizer retains the established horizontal and vertical paging behavior and
must not also invoke tap.

Closing the queue must not reset, duplicate, or consume the record gesture.
One completed vertical gesture still changes at most one track, and track
handoff behavior remains unchanged.

## Verification

Add focused regression coverage proving:

- queue scroll start cancels an existing timer;
- scroll/snap settle starts a two-second timer and the queue then closes;
- a second interaction before expiry restarts the full two-second interval;
- record pointer-down starts dismissal and tap toggles play/pause exactly once;
- record drags dismiss the queue while retaining existing cardinal swipe
  behavior;
- transport, mode, progress, volume, playlist handle, app-bar, and back actions
  dismiss an open queue before continuing their existing behavior;
- the bottom queue button opens `PlayQueueSheet` instead of the folded queue;
- reopening the folded queue centers the current track;
- reduced-motion, accessibility, queue selection, lyrics, and track-handoff
  regressions continue to pass.

## Workspace boundary

The checkout contains unrelated server, lyrics, navigation, search, download,
and planning changes. Modify only the player/queue widgets, their focused tests,
and these plan documents. Do not reset, clean, broadly stage, commit, push,
deploy, or touch production.
