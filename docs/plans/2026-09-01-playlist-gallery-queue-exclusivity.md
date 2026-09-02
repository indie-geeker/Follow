# Playlist Gallery Queue Exclusivity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make a confirmed playlist-gallery pull close the exposed playback queue while preserving the queue after a cancelled pull.

**Architecture:** Keep the existing independent gesture regions and make only their committed terminal states mutually exclusive. Normalize the record, queue reveal, and lyrics state when the playlist gallery successfully opens; do not change state at drag start.

**Tech Stack:** Flutter 3.44.8, Riverpod, `flutter_test`

---

### Task 1: Reproduce the conflicting terminal state

**Files:**

- Test: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Steps:**

1. Open the folded queue through the record gesture.
2. Perform a confirmed top pull and assert the queue becomes hidden and the record returns to its centered horizontal position.
3. Perform a below-threshold top pull in a separate setup and assert the queue remains open.
4. Run the focused test and confirm the committed-open assertion fails before production code changes.

### Task 2: Normalize state when the gallery opens

**Files:**

- Modify: `follow/lib/features/player/player_page.dart`

**Steps:**

1. In the successful branch of `_handlePlaylistPullEnd`, close the queue, clear reveal progress, reset record and lyrics offsets, and switch to record mode.
2. Leave below-threshold and cancelled pulls unchanged.
3. Run the focused regression tests and require them to pass.

### Task 3: Verify the scoped repair

**Files:**

- Verify: `follow/lib/features/player/player_page.dart`
- Verify: `follow/test/features/player/interactive_lyrics_integration_test.dart`

**Steps:**

1. Format only the two changed Dart files.
2. Run the player integration test file.
3. Run scoped Flutter analysis and `git diff --check`.
4. Review the scoped diff and preserve all unrelated dirty-tree changes.
5. Do not commit, push, deploy, or touch production.
