# Mobile Player Stable Layout and Queue Design

**Date:** 2026-08-31

## Goal

Keep the mobile player vertically stable when paging between cover art and
lyrics, give lyrics more usable height, separate the page indicator from the
visual content, keep the transport controls geometrically centered, and expose
the active playback queue from the right side of the controls row.

## Current Cause

The cover and lyrics already share the same fixed-height `PageView`, so their
component heights are not the direct cause of the jump. The cover page renders
a variable-height title and artist block below the page indicator, while the
lyrics page substitutes a fixed 60-pixel spacer. Switching pages therefore
changes the height consumed below the shared viewport and makes the surrounding
flex space redistribute.

The cover itself is fixed at 280 pixels inside a larger viewport. The shared
viewport can grow without enlarging the cover; the additional space benefits
the lyrics view.

## Layout

Use one stable responsive shell for both cover and lyrics:

1. A shared flexible `PageView` receives the remaining upper-page height.
2. Cover art remains 280 pixels and is centered within that viewport.
3. `InteractiveLyricsView` fills the same viewport and therefore reveals more
   lines on taller devices.
4. A fixed gap separates the viewport from the two page-indicator dots.
5. A fixed-height track-information slot follows the indicator. It renders the
   title and artist on the cover page and preserves the same empty height on the
   lyrics page.
6. Progress, volume, playback controls, and bottom safe spacing keep stable
   positions while the page changes.

The upper region remains responsive instead of introducing different cover and
lyrics heights. This prevents a page change from moving the lower controls and
lets compact devices allocate less visual height without changing interaction
semantics.

## Playback Controls

Render `PlayerMainControls` as a full-width `Stack`:

- Align the single existing mode button to the left. It continues to cycle
  sequence, shuffle, and single-track modes through `playerModeProvider`.
- Center a compact row containing previous, play/pause, and next. Its center is
  independent of both side actions.
- Align a queue button to the right with the tooltip `当前播放队列`.

The controls widget receives an `onShowQueue` callback. `PlayerPage` owns the
modal presentation so the controls component stays focused on layout and
actions.

## Queue Sheet

The queue button opens a scroll-controlled transparent modal bottom sheet and
reuses the existing `PlayQueueSheet`. The sheet continues to read
`playQueueProvider` and `currentTrackProvider`, and it continues to delegate
selection, removal, and clearing to `AudioPlayerService`.

An empty queue with a current track keeps the existing fallback that displays
that track. Existing queue error and mutation behavior is unchanged.

## Testing

Follow red-green-refactor with focused Flutter widget tests:

- prove the visual viewport is taller than the old mobile value on the standard
  390 x 844 test device;
- prove the progress area does not change vertical position after paging between
  cover and lyrics;
- prove the indicator has explicit separation from the shared viewport;
- prove previous/play/next remain centered independently of the side actions;
- prove mode remains on the left and the queue action is on the right;
- prove tapping the queue action opens `PlayQueueSheet` with the active queue;
- rerun the existing interactive lyrics, control, and queue-sheet tests.

No desktop lyrics layout, lyric timing model, parser, provider, backend, or saved
playlist contract changes are included.
