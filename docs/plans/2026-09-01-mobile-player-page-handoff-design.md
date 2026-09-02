# Mobile Player Page Handoff Design

## Problem

When a vertical record swipe settles, `PlayerCoverArt` currently resets its
page offset before invoking the playback callback. That reset animates the old
current page back into view and moves the already-centered adjacent page away.
Because queue index changes can also precede `currentTrack`, the adjacent page
may be remapped before playback has actually changed tracks.

The folded queue also stays open during a vertical record gesture because the
player preserves `_queueOpen` for vertical visual offsets.

## Approved behavior

- A vertical drag keeps the folded queue visible. The queue closes only after
  the released gesture is accepted and the adjacent record finishes settling
  at center. A cancelled short swipe leaves the queue open.
- A completed vertical page turn keeps the incoming adjacent record centered
  while playback changes.
- Adjacent pages remain anchored to the displayed `currentTrack`, not a queue
  index that may already point to a pending track.
- When `currentTrack` changes to the expected adjacent track, the new current
  page is rebased to the center with no transition. There is no second entry
  animation from the opposite direction.
- Horizontal record/lyrics/queue gestures and reduced-motion behavior remain
  unchanged.
- Every `track.id` change resets the current record rotation to zero before
  playback-driven rotation resumes, including when returning to a previously
  played track.

## State handoff

`PlayerCoverArt` records the expected adjacent track id when a vertical page
turn completes. After the settle animation, it invokes the playback callback
without resetting the vertical page offset. `didUpdateWidget` recognizes the
expected track change, clears the gesture state synchronously, and suppresses
the next page transform animation.

If the expected adjacent track is absent or is the same track, the component
resets immediately after invoking the playback callback because no distinct
track identity change can complete the handoff.

`PlayerPage` keeps the folded queue state unchanged while receiving vertical
record offsets. The settled vertical swipe callback closes the queue before it
starts previous/next playback. Preview neighbors are derived from the displayed
track's queue position.

`PlayerCoverArt.didUpdateWidget` resets the rotation controller whenever the
displayed track id changes, then synchronizes rotation with the current playing,
busy, settling, and reduced-motion states.

## Verification

- Widget regression test for holding the incoming page at center until the
  expected track arrives, then rebasing without reverse animation.
- Player integration regression test for preserving an open queue during a
  vertical drag/cancel and closing it only after a completed page settle.
- Cover regression test that advances rotation, changes track identity, and
  verifies the new record starts from angle zero.
- Existing cardinal-axis, lyrics pager, queue reveal, rotation, reduced-motion,
  static analysis, and full Flutter tests.
