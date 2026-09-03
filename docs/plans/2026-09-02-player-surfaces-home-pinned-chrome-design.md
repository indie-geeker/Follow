# Player Surfaces and Home Pinned Chrome Design

## Context

The mobile player and home screen currently let decorative cover-derived color leak into surfaces whose primary job is interaction or reading. Three symptoms follow:

- The folded playback queue still looks like a bordered panel even though its literal `Border.all` was removed, because a rounded clipped blur and gradient still create a hard visual boundary.
- The playlist gallery empty-state copy sits on a translucent, cover-tinted glass surface, so the final composited background is not stable enough to guarantee readable text.
- The pinned home tabs stop at 82% opacity while the system status-bar inset remains transparent, so artwork remains visible through two parts that should read as one fixed navigation surface.

## First-principles rule

Decorative color may create atmosphere, but controls and text need a deterministic visual ground. A boundary is perceived whenever clipping, blur, or luminance changes abruptly; removing only a border object does not remove that boundary. Text contrast must be evaluated against the final composited surface, not against an assumed theme color.

## Approved design

### Folded playback queue

Keep the existing transparent layout and gesture area, reveal animation, scrolling, cover selection rings, shadows, and accessibility semantics. Remove the outer `ClipRRect`, `BackdropFilter`, and palette gradient entirely. The queue becomes a set of floating circular covers without a rectangular or rounded background silhouette.

### Playlist gallery

Use one opaque semantic surface across the gallery. In light mode it uses the existing near-white `surface` token; in dark mode it uses the corresponding dark surface. Cover-derived palette colors remain available for the illustration and playlist-record accents, but do not sit behind labels or empty-state copy. Empty-state title and description use explicit semantic foreground colors so their contrast remains stable for every cover palette.

### Home pinned chrome

During expansion, preserve the current aurora header. As collapse reaches the pinned state, fade in the semantic surface across the entire collapsed sliver, including the top system inset and the 48dp tab row. At full collapse the surface is fully opaque. The status bar remains edge-to-edge but is visually backed by the same surface as the tabs, and system icon brightness follows the active theme.

## State and interaction boundaries

No playback, playlist selection, queue ownership, pull threshold, swipe direction, timer, or navigation behavior changes. This design changes only compositing and color ownership. Existing transient-layer mutual exclusion remains intact.

## Validation

- Widget tests prove the folded queue has no backdrop/filter/gradient surface while its interaction area remains.
- Gallery tests cover empty data in light and dark themes, assert an opaque surface, and verify title/body foreground roles.
- Home-collapse tests assert the expanded state remains transparent, the fully pinned tab and status-inset surfaces are opaque and identical, and system overlay icon brightness matches the theme.
- Focused tests run red before implementation and green afterward, followed by formatting, scoped analysis, the full Flutter suite, a debug APK build, and Android emulator screenshots for the three reported states.

## Delivery constraints

Preserve unrelated work. Do not push, deploy, or modify production. Do not commit unless the user explicitly requests it.
