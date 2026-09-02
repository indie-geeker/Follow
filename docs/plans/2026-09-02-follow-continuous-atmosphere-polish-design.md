# Follow Continuous Atmosphere Polish Design

## Goal

Remove visible color seams between system chrome, page headers, player layers,
the folded queue, and lyrics while preserving the approved cover-adaptive
aurora language and existing gesture ownership.

## Home

The home page owns one edge-to-edge `AuroraBackground` that paints behind the
status bar and the complete scroll viewport. The nested scroll view no longer
owns the top safe-area inset. Instead, the collapsing header includes the
status-bar height in its expanded and collapsed extents, while its interactive
content receives top safe padding.

`HomeAuroraHeader` paints only atmospheric artwork over the shared scene. Its
gradient uses palette colors that fade to transparent at the bottom so it does
not read as a separate rectangular surface. The pinned tab surface keeps a
small readability scrim only when collapsed.

## Player chrome and transient layers

The player remains one cover-adaptive scene. The title bar does not own a
separate opaque band: it uses a palette-tinted blur/scrim over the same
background. During a playlist pull, the title-bar tint interpolates with the
gallery reveal so the player chrome and gallery do not form two horizontal
color blocks.

The playlist gallery continues to paint behind the translated player and keeps
its existing 88dp open threshold. Gesture ownership and queue exclusivity do
not change.

## Folded queue

The folded queue keeps its rounded silhouette and accessible scrolling, but
the strong neutral `GlassPanel` is replaced by a palette-tinted translucent
surface. The surface uses the same cover palette as the player, a low-opacity
fill, subtle blur, and a very weak inner border. It must never become an
independent white card in light mode.

## Lyrics

Mobile lyrics render directly in the shared player scene. The surrounding
`GlassPanel`, panel border, and card-shaped horizontal margin are removed.
The lyrics keep their existing safe horizontal gutter, semantics, timed
highlighting, browsing indicator, and swipe-back gesture. The bottom control
deck remains a separate glass control surface.

## Accessibility and motion

Status-bar icon brightness follows the active theme. Minimum tap targets,
semantic labels, reduced-motion behavior, and the established record/lyrics,
queue, and playlist gestures remain unchanged.

## Validation

- Home background reaches the physical top edge while header controls remain
  below the status bar.
- Expanded header fades continuously into the body and collapsed tabs remain
  readable.
- Closed and open playlist states do not expose a distinct title-bar stripe.
- Folded queue surface is palette-tinted rather than neutral white.
- Mobile lyrics contain no surrounding `GlassPanel` or rounded panel border.
- Existing gesture, lyrics, player, golden, full test, analyze, and debug APK
  checks remain green.
