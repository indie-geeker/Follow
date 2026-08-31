# Interactive Lyrics Scrolling Design

**Date:** 2026-08-31

**Status:** Approved

**Scope:** Flutter mobile and desktop clients

## Summary

Add a shared interactive lyrics view for mobile and desktop. Users can freely
scroll through lyrics without playback immediately pulling the list back. While
browsing, the lyric nearest the vertical center becomes the selected line and a
play arrow appears beside it. The arrow seeks playback to that line. If the user
stops interacting for three seconds, the view returns smoothly to the lyric that
is currently playing.

The feature changes only the Flutter client. It does not require server, API,
lyrics format, or audio-service contract changes.

## Existing Behavior and Problem

Mobile lyrics are rendered in `PlayerPage`; desktop lyrics are rendered in
`LyricsOverlay`. Each implementation owns a separate `ScrollController` and
schedules `animateTo` from a post-frame callback as playback position changes.

This creates three problems:

- playback-driven scrolling competes with touch, wheel, and trackpad input;
- both implementations estimate position using a fixed 48-pixel row height,
  which is inaccurate for wrapped lyrics;
- mobile and desktop duplicate behavior and can drift apart.

Both implementations already support seeking by tapping a lyric line. That
behavior remains available.

## Goals

- Let users browse lyrics by touch, wheel, trackpad, scrollbar, or keyboard.
- Never let automatic following interrupt active manual browsing.
- Show a vertical-center play affordance for the selected browsing line.
- Seek to the selected line when its play arrow is activated.
- Return to the currently playing lyric after three seconds of inactivity.
- Provide identical behavior on mobile and desktop.
- Preserve direct lyric-line seeking and the player's current play/pause state.

## Non-Goals

- Editing or synchronizing lyric timestamps.
- Karaoke-style word-level timing.
- Persisting a browsing position between pages, sessions, or songs.
- Changing the lyrics API, LRC parser, or audio playback backend.
- Redesigning the surrounding player controls, artwork, or track information.

## Chosen Architecture

Create a shared widget:

`follow/lib/shared/widgets/lyrics/interactive_lyrics_view.dart`

`InteractiveLyricsView` owns rendering and transient interaction state. Mobile
`PlayerPage` and desktop `LyricsOverlay` retain their surrounding layouts and
embed this widget in place of their current lyric lists.

The public input stays small:

```dart
InteractiveLyricsView(
  lyrics: lyrics,
  currentIndex: currentLyricIdx,
  onSeek: audioService.seek,
  foregroundColor: foregroundColor,
)
```

The exact API may use a color resolver or style object if that better fits the
existing theme code, but playback and transient scrolling state must not be
moved into the widget's public interface.

### State Ownership

| State | Owner |
| --- | --- |
| Current track and playback position | Existing Riverpod audio providers |
| Current playing lyric index | Existing `currentLyricIndexProvider` |
| Loaded lyrics | Existing `currentTrackLyricsProvider` |
| Follow or browse mode | `InteractiveLyricsView` |
| Center-selected lyric | `InteractiveLyricsView` |
| Three-second inactivity timer | `InteractiveLyricsView` |
| Programmatic-scroll guard | `InteractiveLyricsView` |

Transient browsing state stays local because it belongs to one visible lyric
viewport. It must not survive closing the page or overlay, and it must not leak
between mobile and desktop presentations.

### Existing Components to Change

- `follow/lib/features/player/player_page.dart`
  - remove the page-owned lyric `ScrollController`;
  - remove playback-driven post-frame scrolling;
  - replace the lyric `ListView` with `InteractiveLyricsView`.
- `follow/lib/features/player/lyrics_overlay.dart`
  - remove the overlay-owned lyric `ScrollController`;
  - remove playback-driven post-frame scrolling;
  - use `InteractiveLyricsView` in both narrow and wide layouts.
- `follow/lib/data/providers/lyrics_provider.dart`
  - keep calculating only the lyric corresponding to playback position;
  - do not store the temporary browsing line globally.
- `follow/lib/data/providers/audio_provider.dart`
  - keep the existing `AudioPlayerService.seek` contract unchanged.

## Interaction State Model

The component has two user-visible modes.

```text
Follow mode
   | touch drag / wheel / trackpad / scrollbar / keyboard scroll
   v
Browse mode -- more scrolling --> update center line and restart idle timing
   |
   +-- play arrow --> seek center line --> follow mode
   |
   +-- three seconds idle --> return to playing lyric --> follow mode
```

### Follow Mode

- Keep the current playing lyric near the vertical center.
- Use the existing playing-line emphasis.
- Hide the center play arrow and guide line.
- Start a follow operation only when `currentIndex` changes. Ordinary playback
  position updates must not repeatedly call `animateTo`.

### Browse Mode

- Enter immediately when user-originated scrolling is detected.
- Cancel or suspend playback-driven scrolling.
- Select the visible lyric whose line center is closest to the viewport center.
- Show a fixed center guide and play arrow for the selected line.
- Continue updating the true playing-line highlight without moving the list.
- Restart the idle timer whenever the user interacts again.
- Start the three-second countdown after drag or scroll activity ends.

### Return to Playback

- After three seconds without user interaction, animate to the true playing
  lyric.
- Hide the center indicator only after the return animation completes.
- If the user interacts during the return animation, cancel it immediately and
  remain in browse mode.

### Seeking

- Activating the center arrow seeks to the center-selected lyric timestamp.
- Directly activating a lyric line continues to seek to that line.
- Seeking preserves play/pause state: playback continues if already playing;
  paused playback remains paused.
- A successful arrow seek returns the component to follow mode.
- A failed seek leaves the browsing position visible and reports through the
  existing playback error path rather than crashing the view.

## Scroll and Positioning Design

Use Flutter-native scrolling primitives and do not add a package solely for
this feature.

### Center Selection

- Give lyric rows stable identifiers that allow visible rows to be measured.
- During user scrolling, compare each visible row's center with the lyric
  viewport's vertical center.
- Select the row with the smallest distance.
- If two rows are equally close, prefer the row in the current scroll direction;
  if there is no direction, prefer the earlier row for deterministic behavior.
- Empty display rows do not participate in selection.

### Variable Heights

Lyrics may wrap, so positioning must not use `index * 48` as the final offset.

- Add dynamic top and bottom space so the first and final lyric can each reach
  the viewport center.
- Use actual laid-out row geometry for final centering.
- If a distant target row is not currently laid out, first move to an estimated
  vicinity and then perform an exact geometry-based alignment on the next frame.
- Preserve full lyric text rather than clipping it to enforce a fixed row height.

### User Versus Programmatic Scrolling

Use scroll notifications plus pointer-signal handling to cover:

- touch drag and inertial movement;
- mouse wheel;
- trackpad scrolling;
- scrollbar dragging;
- keyboard scroll actions.

Set an internal programmatic-scroll flag around follow, return, and seek
animations. Notifications produced by those animations must not enter browse
mode or restart the inactivity timer.

## Visual and Accessibility Design

- Overlay the center indicator on the lyric viewport so it does not scroll with
  the list.
- Show a play triangle of approximately 20 logical pixels with a minimum
  44-by-44 logical-pixel activation area.
- Extend a subtle horizontal guide from the arrow without obscuring lyric text.
- On desktop, use a click cursor and the tooltip `从此处播放`.
- Expose a semantic label such as `从此处播放：<歌词内容>` for accessibility.
- Keep the true playing lyric as the strongest emphasis.
- Use secondary emphasis for a center-selected line that is not playing.
- If selected and playing lines are the same, render one strongest style rather
  than stacking effects.
- Derive arrow, guide, and text opacity from the current foreground color so the
  treatment works in light and dark themes.
- Respect reduced-motion settings by replacing animations with immediate
  positioning.

Recommended motion timings:

| Action | Duration |
| --- | ---: |
| Normal lyric follow | 280 ms |
| Return after inactivity | 400 ms |
| Arrow seek alignment | 220 ms |

## Data Flow

```text
Playback position
  -> currentLyricIndexProvider
  -> InteractiveLyricsView.currentIndex
  -> follow mode: center the playing row
  -> browse mode: update highlight only

User scroll
  -> determine center-selected row
  -> show center indicator
  -> arrow or row activation
  -> onSeek(selected timestamp)
  -> audio player updates playback position
```

## Lifecycle and Edge Cases

- Loading, empty, and failure states do not show the center indicator.
- A single lyric remains centered and does not enter a meaningless browsing
  state.
- Before the first timestamp, the first lyric is current; after the last
  timestamp, the last lyric remains current.
- Duplicate timestamps retain source order and seek deterministically to the
  first matching line.
- A track change, lyric reload, page close, or overlay close cancels timers and
  animations and resets follow mode.
- Widget disposal cancels the timer before disposing the scroll controller so
  no delayed callback can call `setState` or control a dead position.
- A layout breakpoint change preserves the playing lyric as the authoritative
  target and recalculates geometry for the new viewport.

## Testing Strategy

### Pure Logic Tests

- Select the visible row closest to the viewport center.
- Resolve equal-distance rows using scroll direction, then stable source order.
- Start, reset, and cancel the three-second timer.
- Reset browsing state when the lyrics or track identity changes.
- Ignore scroll notifications produced by programmatic movement.

### Widget Tests

- A mobile drag is not interrupted by playback updates.
- The browsed position remains at 2.9 seconds and starts returning after three
  seconds.
- The arrow appears while browsing and disappears after return completes.
- The arrow represents the visually centered lyric and emits its timestamp.
- Direct lyric-line activation still seeks.
- Seeking while paused does not start playback.
- Long wrapped lyrics, the first line, and the last line can be centered.
- A track change does not retain the previous selected line.
- User input during a return animation cancels that animation.
- Disposal with a pending timer produces no exceptions.

### Layout and Platform Tests

- Around 390 logical pixels: touch scrolling, wrapping, and arrow hit area.
- At the 600-pixel narrow/wide breakpoint: rebuild without losing the playback
  target.
- Around 1280 logical pixels: wheel, trackpad, scrollbar, pointer, and tooltip.
- Light and dark themes: indicator and both emphasis levels remain legible.

### Regression Tests

- Mobile artwork/lyrics horizontal paging remains functional.
- Desktop overlay open and close animation remains functional.
- Progress-bar seeking, previous, next, play, and pause remain functional.
- Existing no-lyrics, invalid-format, and network-failure views remain intact.

## Acceptance Criteria

- Manual lyric scrolling is never overridden while the user is interacting.
- Return begins only after three complete seconds without user interaction.
- The center arrow always represents the lyric nearest the visual center.
- Arrow activation seeks to the correct timestamp and preserves play/pause state.
- Current playback highlighting continues while browsing.
- Mobile and desktop expose the same behavior and lifecycle rules.
- No server or API changes are required.
