# Mobile Vinyl Gesture Player Design

**Date:** 2026-09-01

## Goal

Replace the mobile player's square cover-and-page-dot presentation with an
immersive circular vinyl interaction that supports playlist switching, direct
track navigation, lyrics, and queue selection without assigning two meanings
to the same gesture region.

## Interaction Model

The player uses two independent gesture regions:

1. A page-top pull region opens a playlist gallery behind the player.
2. The circular record handles track and content navigation.

Gesture meaning is determined by where the gesture starts, never by trying to
distinguish a short drag from a long drag:

| Start region | Gesture | Result |
| --- | --- | --- |
| Page-top pull region | Pull down | Reveal the playlist gallery |
| Playlist gallery | Swipe horizontally | Preview stacked playlists |
| Centered playlist card | Tap | Replace the queue, play its first track, close the gallery |
| Vinyl record | Swipe up | Play the next track |
| Vinyl record | Swipe down | Play the previous track |
| Vinyl record | Swipe left | Show lyrics |
| Vinyl record | Swipe right | Reveal the folded queue |
| Folded queue | Scroll and tap a cover | Play that queue item |

## Vinyl Surface

The main cover is circular and visually reads as a record:

- the track cover is clipped to a circle;
- subtle concentric groove rings sit above the artwork;
- a dark center label and spindle hole establish the vinyl metaphor;
- the existing square page-indicator dots are removed;
- visible transport controls remain available as an accessible alternative to
  gesture-only navigation.

The record locks to the dominant axis after a small movement tolerance. A
completed drag needs either sufficient distance or velocity. Track changes fire
once on release, provide haptic confirmation, and ignore further record drags
until the asynchronous playback action completes.

## Playlist Gallery

Pulling down from the page-top handle prepares a top playlist shelf. The handle
tracks the drag and shows a continuation hint; crossing the open threshold
produces one haptic event. Reversing the drag reduces that progress. Releasing
below the threshold returns to the player, while releasing beyond it opens a
shelf occupying roughly one third of the phone height.

The shelf uses a horizontal viewport with a large centered playlist record and
smaller, partially visible neighbors. It reads existing `Playlist.coverUrl`,
`name`, and `trackCount` data. Missing artwork falls back to a themed record
placeholder. Selecting the centered playlist fetches its detail, replaces the
play queue, starts the first track, records the playlist as the queue source,
and closes the shelf. Loading and failure remain visible in the shelf and never
discard the current queue before the replacement is ready.

## Folded Queue

Swiping the record right translates it to the right and reveals a queue layer
that was visually underneath it. Queue covers follow a vertical arc on the left
side. The current track is largest and neighboring tracks progressively shrink
and fade. The list is scrollable; tapping a cover plays that queue index while
preserving the playlist source.

The queue closes with a left swipe, its visible close action, or the system back
action. It does not replace the existing queue data model and does not mutate
playlist membership.

## Lyrics

Swiping the record left replaces the record surface with the existing shared
`InteractiveLyricsView`. Lyrics keep ownership of vertical scrolling. A right
swipe or a visible record/back affordance returns to the record surface. The
desktop lyrics overlay and lyric parsing/timing behavior remain unchanged.

## Playback Source State

The playback layer stores an optional source playlist id alongside the existing
queue and current index. Starting arbitrary albums, search results, downloads,
favorites, or history clears the source. Starting a playlist sets it. Selecting
another item in the existing queue preserves it. Clearing or structurally
editing the queue clears it because the queue no longer exactly represents the
playlist.

## Accessibility and Motion

- Gesture functionality retains visible transport and queue alternatives.
- All interactive covers and controls expose semantic labels and at least a
  48dp touch region.
- Direction and selection are communicated with text/icon feedback, not color
  alone.
- Micro-interactions target 220-300ms and use transforms/opacity.
- Reduced-motion mode removes record travel and stacked parallax while keeping
  state changes explicit.
- The design respects safe areas and does not claim device or driving proof
  from widget tests alone.

## Error Handling

- Empty playlists do not replace the current queue and show `歌单暂无歌曲`.
- Playlist-detail failures leave the gallery open with a retry affordance.
- Playback failures use the existing global playback-failure channel and return
  the record to its resting position.
- Empty queues reveal an explanatory empty state instead of interactive covers.

## Verification

Use focused Flutter tests to prove record geometry and gesture direction,
playlist selection and collapse behavior, queue source preservation, queue
selection, lyrics entry/return, empty/error states, and arbitration between top
pull, record drags, and lyric scrolling. Then run formatting, analysis, the full
Flutter test suite, and a debug Android build. Emulator/device visual and
driving validation remain separate release gates.
