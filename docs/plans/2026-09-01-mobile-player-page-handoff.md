# Mobile Player Page Handoff Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the folded queue only after a confirmed vertical page turn, remove reverse entry animation, and reset record rotation for every new track identity.

**Architecture:** Preserve the custom biaxial pager. Hold the settled adjacent page until the displayed track identity changes, then atomically rebase the new current page; keep the queue open during dragging and close it from the accepted swipe callback after settle. Reset the rotation controller on each displayed track identity change.

**Tech Stack:** Flutter, Riverpod, flutter_test

---

### Task 1: Reproduce the page handoff regression

**Files:**
- Modify: `follow/test/shared/widgets/player/player_cover_art_test.dart`
- Modify: `follow/test/features/player/interactive_lyrics_integration_test.dart`

1. Add a stateful cover harness whose swipe callback changes `track` only after
   the incoming page has settled.
2. Assert the adjacent page remains centered between callback and track update.
3. Assert the new current page is centered immediately after track update.
4. Open the folded queue, begin a short vertical drag, and assert the queue
   remains open before release and after cancellation.
5. Complete a vertical page turn and assert the queue closes only after the
   240ms settle callback.
6. Advance a playing record's rotation, change its track identity, and assert
   the replacement record starts at angle zero.
7. Run the focused tests and confirm they fail for the current early close and
   preserved rotation angle.

### Task 2: Implement identity-based page handoff

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_cover_art.dart`

1. Store the expected adjacent track id for a completed vertical turn.
2. Invoke playback after settle without resetting the page offset.
3. In `didUpdateWidget`, recognize the expected track identity, clear the drag
   state, and suppress the next page transform animation.
4. Reset immediately for missing or same-track adjacent pages.
5. Reset the rotation controller value when `track.id` changes, before
   synchronizing the playing state.
6. Run the focused cover tests and existing cover suite.

### Task 3: Close the queue and stabilize preview order

**Files:**
- Modify: `follow/lib/features/player/player_page.dart`

1. Preserve `_queueOpen`, `_queueRevealProgress`, and the record resting offset
   during vertical drag updates and cancelled swipes.
2. In accepted `onSwipeUp` and `onSwipeDown` callbacks, close the queue after
   the pager settle and before starting playback.
3. Derive previous/next preview indices from the displayed current track's
   position in the queue, falling back to `currentIndex` only when absent.
4. Run the focused player integration tests and full player integration suite.

### Task 4: Verify

1. Run `dart format` on changed Dart files.
2. Run `flutter analyze`.
3. Run `flutter test`.
4. Run `git diff --check` and review only the scoped player changes.

No commit or push is included because this checkout already contains unrelated
uncommitted work and the user did not authorize version-control mutations.
