# Enhanced LRC Word Highlighting Design

**Date:** 2026-08-31

**Status:** Approved

**Scope:** Flutter mobile and desktop lyric rendering, with server pass-through verification

## Summary

Add optional word- or character-level highlighting when a lyric line contains
Enhanced LRC inline timestamps. Preserve the existing whole-line highlighting
for ordinary LRC. Never infer timing by distributing a line duration across its
text.

The first supported enhanced syntax is:

```lrc
[00:12.00]<00:12.00>我<00:12.30>爱<00:12.55>你
```

The line timestamp remains the authoritative seek and scrolling timestamp.
Each inline timestamp marks when the following text segment becomes
highlighted.

## Existing Architecture

The server reads embedded lyrics through `TagLib.File.Tag.Lyrics`, accepts a
bounded document containing at least one ordinary LRC line timestamp, and
writes the text unchanged as `lyrics/{trackId}/lyrics.lrc`.

The Flutter client fetches that object, parses each timed line into
`LyricLine(timestamp, text)`, derives the current line from the audio position,
and renders mobile and desktop lyrics through the shared
`InteractiveLyricsView`.

## Chosen Approach

Use Enhanced LRC inline timestamps as an optional extension of the current LRC
contract.

- Ordinary line: `[mm:ss.xx]text`
- Enhanced line: `[mm:ss.xx]<mm:ss.xx>segment<mm:ss.xxx>segment`
- Both two- and three-digit fractional seconds are accepted.
- Inline timestamps are absolute track positions.
- Source text between adjacent inline timestamps is one indivisible segment.
- Segment text is never split or retimed by the application.

Native ID3 `SYLT` is out of scope because the current generic TagLib lyrics
property does not expose it consistently across media containers. TTML and JSON
are also out of scope because they would require a broader upload and content
contract.

## Data Model

Extend the existing model without breaking ordinary callers:

```dart
class LyricSegment {
  final Duration timestamp;
  final String text;
}

class LyricLine {
  final Duration timestamp;
  final String text;
  final List<LyricSegment> segments;
}
```

`segments` defaults to an empty constant list. `text` always contains the clean,
displayable full line without inline timing markers. This preserves seeking,
scrolling, accessibility labels, and existing test fixtures.

## Parsing and Fallback

Parse the ordinary line timestamp first. Then inspect the remaining text for
inline timestamps.

An enhanced line is valid only when:

- it contains at least one inline timestamp;
- no visible text appears before the first inline timestamp;
- every inline timestamp is valid and timestamps are non-decreasing;
- every timestamp has non-empty following text before the next timestamp or end
  of line.

For a valid line, concatenate segment text to produce `LyricLine.text` and keep
the parsed segments. For an invalid enhanced line, remove recognizable inline
timestamp markers, preserve the readable text, and return an ordinary
`LyricLine` with no segments. Invalid enhanced metadata must never make the
whole lyrics document unavailable and must never show raw timing markup.

Ordinary LRC behavior remains unchanged.

## Rendering

Add a small shared lyric-text widget used by `InteractiveLyricsView`.

- On the current line with segments, segments whose timestamp is less than or
  equal to the playback position use the highlighted foreground color.
- Future segments use the current line's inactive color.
- On a current line without segments, the entire line retains the current
  whole-line highlight.
- Non-current and browse-selected lines retain their existing whole-line styles.
- Highlight changes occur only at supplied timestamps. There is no fabricated
  character timing or fractional sweep inside a segment.
- The parent semantics node continues to expose the clean full lyric line once,
  rather than exposing one accessibility node per segment.

`InteractiveLyricsView` receives the current playback position in addition to
the current line index. `PlayerPage` and `LyricsOverlay` already observe that
position for their progress controls, so no new playback service is required.

## Interaction Compatibility

The enhancement must preserve:

- automatic centering of the playing line;
- uninterrupted manual lyric browsing;
- center-line seek and direct line tap seek;
- the three-second return to the playing line;
- seek ownership and stale-operation protection;
- reduced-motion behavior;
- mobile and desktop parity.

When browsing away from the playing line, only the true playing line may show
segment progress. The selected browsing line keeps the existing selected-line
style until it becomes the playing line after a successful seek.

## Server Boundary

No database, API, object naming, or content-type change is required for the
chosen syntax. Add characterization coverage proving that Enhanced LRC stored
inside the generic embedded lyrics text is preserved unchanged by normalization,
TagLib extraction, and managed lyric-object writing.

## Testing

Cover:

- unchanged ordinary LRC parsing and whole-line rendering;
- Chinese character and English word segments;
- mixed enhanced and ordinary lines;
- two- and three-digit fractional seconds;
- duplicate and boundary timestamps;
- malformed, incomplete, and decreasing inline timestamps falling back safely;
- seek and playback-position updates changing the highlighted segments;
- full-line accessibility semantics without per-segment duplication;
- existing mobile, desktop, scrolling, and lifecycle regression suites;
- server pass-through of embedded Enhanced LRC.

## Delivery Boundaries

This work is local only. Do not commit, push, deploy, upload media, modify real
music files, or touch production services.
