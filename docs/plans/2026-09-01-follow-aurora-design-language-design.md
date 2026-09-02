# Follow Aurora Design Language

**Date:** 2026-09-01

## Status

Approved by the user on 2026-09-01. This document defines the visual and
interaction target only. It does not prove implementation, build success,
device performance, or release readiness.

## Goal

Replace Follow's scattered page-level colors, typography, radii, and state
views with a coherent light/dark design system. The product uses an immersive
aurora identity, while the player adds bounded glassmorphism and safe dynamic
colors derived from the active cover.

The redesign may be structurally destructive, but it must preserve the current
music and gesture contracts: the mobile vinyl surface, playlist pull gesture,
queue reveal, lyrics browsing, visible transport alternatives, stable record
region, and stable track-information slot.

## Product Character

The target character is:

- immersive, translucent, contemporary, and calm;
- recognizable through midnight indigo, violet, coral-pink, and restrained
  cyan highlights;
- content-first outside the player;
- visually expressive inside the player;
- consistent across light and dark themes without treating one theme as an
  inverted copy of the other;
- accessible and responsive before decorative effects are applied.

The approved direction is **Guarded Adaptive Aurora**. Cover artwork may
influence atmosphere and emphasis, but it must not control text colors,
functional status colors, or critical interaction states.

## Design Principles

1. Use semantic tokens instead of raw page-level values.
2. Keep ordinary pages readable and relatively quiet; reserve the strongest
   glass and aurora effects for playback.
3. Use one blurred cover backdrop and a small number of grouped glass panels.
   Do not stack an independent expensive blur behind every button.
4. Treat empty, no-result, offline, failure, and loading as different states.
5. Every non-loading state has a purpose-built SVG illustration, concise
   guidance, and an appropriate recovery or next action.
6. Color never carries status by itself.
7. Existing gestures retain visible controls and accessibility semantics.
8. Reduced-motion mode remains a complete usable experience.

## Foundation Tokens

### Brand and Theme Colors

| Role | Light | Dark |
| --- | --- | --- |
| Background | `#F7F6FC` | `#090D18` |
| Surface | `#FFFBFF` | `#141A2A` |
| Elevated surface | `#ECEAF4` | `#232B42` |
| Primary text | `#181720` | `#F4F2FA` |
| Secondary text | `#5C5968` | `#C8C5D3` |
| Brand primary | `#5B46F0` | `#A99CFF` |
| Brand secondary | `#B62D71` | `#FF8FC5` |
| Aurora cyan | `#2A8EAF` | `#67D4FF` |

The approved fixed foreground/background pairs have a contrast ratio between
approximately 5.8:1 and 17.5:1. Runtime contrast gates still apply to every
cover-derived accent.

Success, warning, error, offline, and informational colors are fixed semantic
roles. They never come from cover artwork and always appear with iconography or
text.

### Typography

Use the platform system sans family for Chinese, English, and numbers. Avoid a
decorative Latin face that produces a visibly unrelated Chinese fallback. The
`FOLLOW` wordmark may use a geometric semibold treatment without becoming the
app's body typeface.

| Role | Size / line height | Weight | Use |
| --- | --- | --- | --- |
| Display | 32 / 40 | 700 | Hero and important state title |
| H1 | 28 / 36 | 700 | Page title |
| H2 | 24 / 32 | 700 | Player track and major section |
| Title | 20 / 28 | 600 | Card, dialog, and sheet title |
| Item | 16 / 24 | 600 | Track, playlist, album, artist |
| Body | 16 / 24 | 400 | Primary body copy |
| Helper | 14 / 20 | 400 | Artist and supporting copy |
| Label | 12 / 16 | 600 | Navigation, time, and compact status |

Playback time uses tabular figures. Dynamic text may wrap important content;
it must not silently remove titles or actions.

### Spacing, Shape, and Icons

- Spacing scale: `4, 8, 12, 16, 24, 32, 48`.
- Input radius: 12.
- Card radius: 16.
- Large glass panel and bottom-sheet radius: 24.
- Fully circular controls use a circle rather than an arbitrary large radius.
- Icon sizes: 20, 24, and 32, with at least a 48x48dp interaction region.
- Use one rounded, consistent vector icon language. Outline and filled forms
  may distinguish inactive/active states at the same hierarchy.

## Glass System

Glass is a material hierarchy, not a decoration applied to every container.

| Tier | Blur | Intended use |
| --- | ---: | --- |
| Light glass | 12-16 | Toolbar, compact badge, navigation chrome |
| Standard glass | 18-24 | Search, cards, player controls |
| Strong glass | 24-28 | Lyrics, queue, dialog, bottom sheet |

Dark glass uses the dark surface at roughly 50%-68% opacity. Light glass uses
the light surface at roughly 70%-88%. Each tier has a one-pixel translucent
edge highlight. Shadows remain soft and low contrast.

Multiple non-overlapping player panels share one `BackdropGroup`. The full
cover background is blurred once as an image layer. This gives the entire page
a glass reading without multiplying expensive backdrop passes.

## Dynamic Player Palette

### Flow

```text
cover image
  -> downsampled content color extraction
  -> reject unusable extremes and low-information results
  -> map to safe light/dark tones
  -> cache by cover identity and brightness
  -> expose primary, secondary, ambient, and glow roles
```

Cover-derived colors may affect:

- the blurred full-screen cover atmosphere;
- two restrained radial aurora glows;
- the vinyl edge glow;
- playback progress and the primary playback control;
- a small tint in glass surfaces.

Cover-derived colors may not affect:

- primary and secondary text colors;
- error, warning, success, and offline colors;
- disabled semantics;
- destructive actions;
- focus and screen-reader meaning.

Near-black, near-white, transparent, monochrome, invalid, and missing artwork
falls back to the violet/coral brand palette. Palette extraction is cached and
deduplicated. A cover change crossfades the atmosphere over about 360ms without
moving layout.

## Player Composition

The player is built in four visual layers:

1. A scaled cover backdrop with approximately 48-56 equivalent blur and
   controlled saturation.
2. A theme scrim: deep indigo in dark mode or a milky veil in light mode.
3. Two restrained cover-derived radial aurora glows.
4. Foreground content and grouped glass panels.

The mobile player retains:

- the 280px normal record target;
- one flexible visual region shared by record, lyrics, and folded queue;
- a reserved 104px track-information slot on normal-height phones;
- independent centering of the primary transport controls;
- the queue action and visible previous/next/play alternatives;
- top pull for playlist selection;
- vertical record gestures for adjacent tracks;
- horizontal record gestures for lyrics and queue;
- the current timed/interactive lyrics behavior;
- the current reduced-motion and gesture-arbitration rules.

The progress, time, volume, and transport controls form one standard glass
control deck. Lyrics, queue, playlist gallery, and modal sheets use strong
glass. Desktop cover-derived styling remains scoped to player and lyric
surfaces; it does not tint the whole desktop shell.

## Page-Level Application

- Login: aurora background with one strong glass authentication card.
- Home: calm base surface, confident H1, restrained aurora accents, content
  cards without heavy blur.
- Library: consistent section headers, search, tabs, cards, and list density.
- Search: standard glass search field; no-result and failure states use the
  shared state system.
- Downloads: segmented control and progress surfaces use semantic tokens;
  empty/offline states are distinct.
- Settings: grouped tonal surfaces; destructive actions remain spatially and
  semantically separate.
- Mobile navigation: light glass chrome with clear icon-plus-label selection.
- Desktop navigation: tonal rail and stable selected-state treatment.
- Player and lyrics: the only full dynamic-cover environment.

## Illustrated State System

Each state uses a distinct multi-layer SVG rather than a substituted Material
icon.

| State | Illustration | Primary action |
| --- | --- | --- |
| Empty library | Record orbit and sound waves | Add music |
| Empty playlist | Two records waiting to connect | Add tracks |
| No search results | Record crossed by a scanning beam | Clear filters |
| No lyrics | Record and blank lyric tracks | Return to record |
| Empty downloads | Cloud waveform landing in a record | Browse music |
| Offline | Broken waveform bridge | View downloads |
| Failure | Record displaced from its orbit | Retry |
| Nothing playing | Still record and unlit tonearm | Open library |

Illustrations expose four semantic color layers: primary, secondary, muted
fill, and line. Standard size is 160-180px on mobile and 220px on desktop.
Loading is represented by geometry-matched skeletons, not by a state
illustration or a blank page.

## Motion

- Press feedback: 120-180ms.
- Panel and page transitions: 220-280ms.
- Cover palette transition: about 360ms.
- Existing vinyl rotation remains the only continuous player motion.
- Aurora glows do not continuously roam by default.
- Reduced-motion mode stops vinyl rotation and spatial scaling and shortens
  color changes to a simple fade or immediate swap.

Animations use transform and opacity where possible and remain interruptible.

## Accessibility and Performance Gates

- Normal text contrast: at least 4.5:1.
- Large text and large UI glyph contrast: at least 3:1.
- Touch targets: at least 48x48dp in the shared cross-platform layer.
- Color is never the sole status indicator.
- Screen-reader labels include action and state, not decorative detail.
- Dynamic text is verified at large scale.
- The player uses one blurred cover image and grouped non-overlapping backdrop
  filters.
- Palette extraction happens once per cover/theme key and never per frame.
- Extreme covers, missing artwork, offline artwork, and extraction failures all
  have deterministic fallbacks.
- Small phone, large phone, tablet/desktop, portrait, and landscape are visual
  QA targets.

## Architecture Boundary

The implementation should establish these responsibilities:

- `ThemeData`: Material component defaults.
- `FollowThemeTokens`: semantic colors, typography, spacing, shape, glass, and
  motion.
- `PlayerPalette`: safe cover-derived roles and fallback.
- `PlayerPaletteResolver`: extraction, filtering, cache, and deduplication.
- `AuroraBackground`: brand and cover-driven backgrounds.
- `GlassPanel`: shared grouped glass material.
- `AppStateView`: illustrated empty, no-result, offline, and failure states.
- shared section-header, button, icon-button, and skeleton components.

Screen widgets must stop depending on `LoginColors`, arbitrary local hex
values, and repeated local text-size/radius definitions. The dynamic player
palette remains a player-local input and does not replace the global
`ColorScheme`.

## Verification Boundary

Completion must report these separately:

1. token and component implementation;
2. focused Flutter tests;
3. full analyze/test/build proof;
4. visual screenshot or golden review;
5. emulator/device performance review;
6. real-device gesture and accessibility review.

Code and widget tests do not prove device blur performance or final visual
acceptance.
