# Enhanced LRC Word Highlighting Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Highlight supplied Enhanced LRC word or character segments at their exact timestamps while preserving ordinary LRC whole-line highlighting.

**Architecture:** Extend `LyricLine` with optional timed segments, parse inline Enhanced LRC timestamps into clean text plus segment metadata, and render timed spans only for the true playing line in the shared `InteractiveLyricsView`. Keep the server contract unchanged and verify that embedded enhanced text passes through intact.

**Tech Stack:** Flutter, Dart 3.10, Riverpod 3, Flutter widget tests, .NET 10, xUnit, TagLibSharp 2.3

---

## Execution Constraints

- Preserve unrelated untracked files.
- Follow `@superpowers:test-driven-development` for production changes.
- Do not commit, push, deploy, upload media, or touch production.
- Run Flutter commands from `follow/` and .NET commands from `follow-server/`.
- After Flutter commands, inspect `follow/pubspec.lock` and restore only command-induced changes if necessary.

### Task 1: Parse Enhanced LRC Without Breaking Ordinary LRC

**Files:**

- Modify: `follow/lib/data/models/lyric_line.dart`
- Modify: `follow/lib/data/services/lyrics_service.dart`
- Modify: `follow/test/data/services/lyrics_service_test.dart`

**Step 1: Write failing model and parser tests**

Add tests for this intended API:

```dart
final lyric = LyricsService()
    .parseLrc('[00:12.00]<00:12.00>我<00:12.30>爱<00:12.550>你')
    .single;

expect(lyric.text, '我爱你');
expect(lyric.segments, [
  const LyricSegment(timestamp: Duration(seconds: 12), text: '我'),
  const LyricSegment(
    timestamp: Duration(milliseconds: 12300),
    text: '爱',
  ),
  const LyricSegment(
    timestamp: Duration(milliseconds: 12550),
    text: '你',
  ),
]);
```

Add separate cases proving that ordinary LRC has no segments, English spaces
are preserved, ordinary and enhanced lines coexist, and invalid enhanced lines
fall back to clean whole-line text without exposing timing markup.

**Step 2: Verify RED**

Run `flutter test test/data/services/lyrics_service_test.dart` from `follow/`.

Expected: FAIL because `LyricSegment` and `LyricLine.segments` do not exist.

**Step 3: Add the minimal model**

Add immutable `LyricSegment(timestamp, text)` equality and hash code. Add
`List<LyricSegment> segments = const []` to `LyricLine` without changing
existing construction sites.

**Step 4: Add the minimal parser**

Share one timestamp parser between line and inline markers. Preserve clean full
text, source-order segments, stable line sorting, and the approved safe fallback.

**Step 5: Verify GREEN**

Run `dart format` on the three changed files, then rerun the focused parser test.

Expected: all parser tests PASS.

### Task 2: Render Supplied Segment Timing

**Files:**

- Create: `follow/lib/shared/widgets/lyrics/timed_lyric_text.dart`
- Create: `follow/test/shared/widgets/lyrics/timed_lyric_text_test.dart`

**Step 1: Write failing widget tests**

At 12.4 seconds, assert that segments starting at 12.0 and 12.3 seconds use the
highlight color while the 12.55-second segment uses the inactive color. Add
cases proving that ordinary current lyrics and non-current enhanced lyrics use
one whole-line `Text`, and that no per-segment semantics nodes are exposed.

**Step 2: Verify RED**

Run `flutter test test/shared/widgets/lyrics/timed_lyric_text_test.dart`.

Expected: FAIL because `TimedLyricText` does not exist.

**Step 3: Implement the minimal widget**

Create:

```dart
class TimedLyricText extends StatelessWidget {
  const TimedLyricText({
    super.key,
    required this.lyric,
    required this.playbackPosition,
    required this.style,
    required this.highlightedColor,
    required this.inactiveColor,
    required this.enableTimedHighlight,
  });
}
```

Use ordinary `Text` unless timed highlighting is enabled and segments exist.
Otherwise use `Text.rich` with one child span per supplied segment.

**Step 4: Verify GREEN**

Format both files and rerun the focused widget test.

Expected: all timed-text tests PASS.

### Task 3: Integrate Playback Position With the Shared Lyrics View

**Files:**

- Modify: `follow/lib/shared/widgets/lyrics/interactive_lyrics_view.dart`
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/lib/features/player/lyrics_overlay.dart`
- Modify: `follow/test/shared/widgets/lyrics/interactive_lyrics_view_test.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Step 1: Write failing integration tests**

Prove that changing position within one line changes supplied segment styles
without scrolling, ordinary lyrics keep whole-line styling, browse-selected
non-playing rows do not show timed progress, seek behavior remains intact, and
both player presentations pass their current position into the shared view.

**Step 2: Verify RED**

Run the interactive lyrics widget and player integration test files.

Expected: FAIL because the shared view lacks a playback-position input and uses
uniform text rows.

**Step 3: Extend the shared contract**

Add required `Duration playbackPosition` to `InteractiveLyricsView` and pass the
already-observed position from `PlayerPage` and `LyricsOverlay`. Do not add a new
provider or playback subscription.

**Step 4: Integrate `TimedLyricText`**

Preserve all existing styles, keys, semantics, gestures, measurements, scrolling,
and seek ownership. Enable segment highlighting only for `isCurrent`. Extend
the lyric replacement snapshot to detect segment timestamp or text changes.

**Step 5: Verify GREEN**

Format changed files and run the timed text, interactive view, and player
integration tests.

Expected: all focused tests PASS.

### Task 4: Verify Embedded Enhanced LRC Pass-Through

**Files:**

- Modify: `follow-server/tests/Follow.Core.Tests/EmbeddedLyricsPolicyTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/TagLibAudioMetadataExtractorTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/EmbeddedTrackAssetWriterTests.cs`

**Step 1: Add characterization coverage**

Use `[00:12.00]<00:12.00>我<00:12.30>爱<00:12.550>你` in normalization,
TagLib extraction, and managed asset writer tests. Assert exact UTF-8 content,
the existing `.lrc` object path, and the existing text content type.

**Step 2: Run focused server tests**

Run the three named test classes with `dotnet test --filter`.

Expected: PASS without production server changes. If not, stop and report the
actual container/tag boundary before changing server behavior.

### Task 5: Regression and Static Verification

**Step 1: Run lyric-related Flutter tests**

Run parser, provider, scroll geometry, failure view, timed text, interactive
view, and mobile/desktop integration test files together.

Expected: all PASS.

**Step 2: Run static analysis**

Run `flutter analyze` from `follow/`.

Expected: no new findings attributable to this change.

**Step 3: Inspect delivery state**

Run `git diff --check`, inspect the scoped diff, and run `git status --short`.

Expected: only approved implementation/test files and these two new plan
documents are changed. Existing untracked playback-metadata plans remain
untouched. Do not commit or push.
