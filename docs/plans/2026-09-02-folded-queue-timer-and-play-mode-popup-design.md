# Folded Queue Timer and Play Mode Popup Design

## Goal

Keep the folded queue available until the user actually scrolls it or operates
outside it, and provide a compact anchored popup for inspecting and selecting
the three playback modes.

## Folded queue timer rules

- Opening the folded queue does not start an auto-close timer.
- The queue may remain open indefinitely while idle.
- Any queue pointer interaction cancels an existing timer immediately.
- Only an actual vertical queue drag followed by snap/selection settle starts a
  fresh two-second auto-close timer.
- Tapping a queue cover, including a cover that animates into the center, does
  not start the timer.
- Any operation outside the folded queue still dismisses it immediately.

`FoldedTrackQueue` distinguishes a pointer interaction from a real scroll
gesture. It reports interaction start for timer cancellation and reports scroll
settle only when pointer movement drove the list vertically. Programmatic
recentering and tap-driven snapping do not report a scroll settle.

`PlayerPage` remains the owner of folded-queue visibility and the two-second
timer. `_showQueue` opens without scheduling. Only the scroll-settled callback
schedules the timer.

## Play mode popup behavior

The existing bottom-left mode button remains a cycle button:

1. list playback;
2. shuffle;
3. single-track repeat.

Every mode-button tap advances once, shows the popup, and restarts its
two-second visibility timer. The popup contains all three tappable rows at the
same time. The active row has a leading check mark; inactive rows retain the
same leading space so text never shifts.

Selecting a popup row sets that mode directly, updates the button icon and
check mark from the same `playerModeProvider`, keeps the popup visible, and
restarts the full two-second timer. Selecting the already-active mode also
restarts the timer without inventing another state transition.

After two seconds without another mode-button or popup-item activation, the
popup fades out with a small downward retreat. Reduced-motion mode changes
visibility immediately.

The popup is non-modal and does not add a screen-wide barrier. Other player
controls remain usable while it is visible.

## Positioning and component ownership

Extract the mode control into a small stateful consumer component that owns:

- an overlay controller/entry;
- a `LayerLink` anchor;
- the two-second popup timer;
- popup show, refresh, and disposal lifecycle.

Render the button through `CompositedTransformTarget` and the popup through
`CompositedTransformFollower`. Both use `Alignment.topCenter`/
`Alignment.bottomCenter` anchors so the popup's horizontal center is exactly
the button's horizontal center at every viewport width. A small vertical gap
separates the popup from the 48dp button target. Do not position it from the
page edge or from the full controls stack.

The popup uses the current surface colors, rounded corners, a subtle border and
shadow, minimum 48dp item heights, and concise Chinese labels:

- `列表播放`
- `随机模式`
- `单曲循环`

## Error and lifecycle handling

Mode state continues to flow through `playerModeProvider`; the popup does not
hold a second copy. Timers are cancelled when the control is disposed. Overlay
content checks that it remains mounted before updating or hiding. Repeated taps
replace the existing timer instead of creating overlapping delayed actions.

## Verification

Widget and integration tests must prove:

- opening the folded queue and waiting longer than two seconds keeps it open;
- a queue tap does not start auto-close;
- a real vertical scroll starts auto-close after settle;
- a new queue interaction cancels and a later scroll restarts the timer;
- external player operations still dismiss immediately;
- the mode button cycles all three provider states and shows the popup;
- all three rows are visible and only the active row is checked;
- popup item selection updates provider state, icon, tooltip, and check mark;
- repeated button and item activation restart the full two-second timeout;
- popup and mode button centers match within layout tolerance;
- reduced-motion, semantics, touch targets, and existing player gestures remain
  intact.

## Workspace boundary

The checkout contains existing uncommitted player, lyric, navigation, server,
test, and planning work. Modify only the folded queue/player controls/player
page paths, focused tests, and this design/plan pair. Do not reset, clean,
broadly stage, commit, push, deploy, or touch production.
