# Follow Home and Player Polish Design

**Date:** 2026-09-02

**Status:** Approved

## Goal

Polish the approved immersive-aurora visual language by unifying the home
header with its content, adding a snapping collapsible tab header, removing
perceived player-entry latency, fixing player layer bleed and backdrop seams,
and improving playback-control spacing.

## Scope

This change covers six reported issues:

1. the home hero and list currently read as separate color blocks;
2. the home tabs should pin below the status bar while the hero snaps open or
   closed;
3. opening the player after choosing a track feels delayed;
4. the player title bar is too transparent and exposes the playlist drawer;
5. changing tracks can briefly paint a horizontal seam through the backdrop;
6. the five primary playback controls are crowded and the mode popup is wider
   than necessary.

Existing record, lyrics, queue, playlist-pull, vertical track-change, and
accessibility behavior must remain intact.

## Home Header

The mobile home page uses one pinned `SliverAppBar` with a zero-height toolbar,
a 48dp tab bottom, and a flexible hero region. The full hero collapses away;
only the tab strip remains pinned below the status bar. Floating and snap
behavior gives the same two stable end states as Android
`AppBarLayout`/`CoordinatorLayout`: below the snap threshold it returns fully
open, and above it it completes the collapse.

The header and content remain inside the same `AuroraBackground`. The tab strip
does not paint a separate opaque surface while expanded. As it approaches the
collapsed state, it gains a restrained glass fill and bottom hairline so text
stays readable over scrolling content without introducing a hard color seam.

### Header Artwork

The hero uses an abstract, cover-inspired record aurora rather than a literal
photo collage:

- a large cropped vinyl-groove motif sits at the upper-right edge;
- two soft cover-derived glows and a subtle waveform/particle trace add depth;
- the greeting and account controls remain the visual priority;
- artwork opacity and scale reduce with the collapse progress.

On a first launch, while history loads, when history is empty, or when history
fails, the same geometry uses deterministic brand purple, aurora cyan, and a
small rose accent. Once the first recent cover palette resolves, the colors
cross-fade without changing geometry or header height. A failed cover keeps the
brand fallback. This prevents blank placeholders, layout jumps, and network
loading indicators in the header.

## Immediate Player Entry

Track selection becomes optimistic at the state boundary:

1. establish the queue/index and publish the selected track synchronously;
2. start source/token preparation without blocking navigation;
3. push the mobile player immediately;
4. let playback, lyrics, and the extracted palette settle asynchronously.

The player therefore paints its first frame from the selected track metadata
and cached/fallback palette. Existing playback failure state clears the
optimistic track and reports a recoverable error. Desktop behavior continues
to await the playback operation and does not open the full-screen player.

## Player Top Chrome and Playlist Reveal

At rest, the title bar has a cover-compatible glass/scrim fill equivalent to
roughly 82% opacity. The playlist drawer remains mounted for gesture continuity
but is both visually transparent and excluded from semantics/pointer input at
zero reveal progress, so its title never bleeds through the top bar.

The pull progress drives a single coordinated transition:

- player scaffold translation: `0 -> galleryHeight`;
- drawer opacity: `0 -> 1`;
- top-chrome opacity: `0.82 -> 0.30`;
- hint text: hidden at rest, then fades into pull/release guidance;
- under-threshold release snaps closed; accepted pull snaps open.

No new full-screen gesture surface is introduced. The playlist handle keeps
ownership of the vertical pull, and existing queue/lyrics layers remain
mutually exclusive.

## Seamless Backdrop Switching

Every outgoing and incoming backdrop is constrained to the complete player
viewport. `AnimatedSwitcher` uses a fixed, expanding stack layout; each cover
layer uses `SizedBox.expand` before blur and scale. The scrim and aurora glows
remain outside the switcher and paint continuously.

The old full-screen cover stays visible until the new image can paint, then the
two full-screen layers cross-fade. Different source aspect ratios or intrinsic
dimensions can no longer resize the switcher or expose a horizontal boundary.
Reduced-motion mode switches without a transition but retains the same fixed
geometry.

## Playback Controls

The five controls use an equal-slot row rather than 4dp spacer pairs. The
primary control remains 56dp; secondary visual buttons may remain compact but
retain at least a 48dp semantic/touch region. Horizontal padding is 12–16dp,
with responsive slots on compact widths. The mode popup narrows from 128dp to
112dp while keeping single-line labels and the existing selected indicator.

## Accessibility and Motion

- Collapsed and expanded headers preserve complete greeting semantics.
- Decorative header artwork is excluded from semantics.
- Playlist content is excluded until reveal progress is non-zero and remains
  non-interactive until fully open.
- All controls retain existing tooltips and TalkBack labels.
- Snap, header artwork, drawer reveal, and backdrop cross-fade become immediate
  when `MediaQuery.disableAnimations` is true.

## Verification

Each behavior is introduced through a failing widget/unit test before
production changes. Focused checks cover header continuity and snapping,
optimistic navigation ordering, hidden/revealed playlist layers, fixed backdrop
geometry across cover changes, control spacing, popup width, compact layouts,
and reduced motion. Existing player interaction suites and goldens then run,
followed by full `flutter analyze`, `flutter test`, debug APK build, and Android
emulator visual/performance checks.

Real-device profile proof remains a separate release gate and is not implied by
local tests or emulator screenshots.
