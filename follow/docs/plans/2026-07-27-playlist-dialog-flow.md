# Playlist Dialog Flow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Add a clear “新建歌单” action to the add-to-playlist dialog and reuse one polished creation dialog from both playlist entry points.

**Architecture:** Extract the Home page's private creation `AlertDialog` into a shared Riverpod-aware dialog. Keep playlist creation in `playlistsProvider`, and let the add-to-playlist dialog open the shared route without dismissing itself so the refreshed playlist list remains in context.

**Tech Stack:** Flutter Material 3, flutter_riverpod, flutter_test

---

### Task 1: Lock the shared dialog contract

**Files:**
- Create: `test/shared/widgets/create_playlist_dialog_test.dart`
- Create: `lib/shared/widgets/create_playlist_dialog.dart`

**Step 1: Write the failing tests**

Cover the visible label and helper copy, disabled empty submit state, trimmed submission, loading feedback, dialog dismissal on success, and inline retryable failure state.

**Step 2: Run the tests to verify RED**

Run: `fvm flutter test test/shared/widgets/create_playlist_dialog_test.dart`

Expected: FAIL because the shared dialog does not exist yet.

**Step 3: Write the minimal implementation**

Create `showCreatePlaylistDialog(...)` and a `CreatePlaylistDialog` that defaults to:

```dart
ref.read(playlistsProvider.notifier).create(name);
```

Use semantic theme colors, a visible `歌单名称` label, 48dp actions, trimmed input, a disabled/loading submit button, and an inline error with a recovery instruction.

**Step 4: Run the tests to verify GREEN**

Run: `fvm flutter test test/shared/widgets/create_playlist_dialog_test.dart`

Expected: all tests pass.

### Task 2: Reuse the dialog from both playlist surfaces

**Files:**
- Modify: `lib/shared/widgets/add_to_playlist_dialog.dart`
- Modify: `lib/features/home/home_page.dart`
- Create: `test/shared/widgets/add_to_playlist_dialog_test.dart`

**Step 1: Write the failing test**

Render `AddToPlaylistDialog`, assert a full-width `新建歌单` action exists, tap it, and assert the shared creation dialog opens.

**Step 2: Run the test to verify RED**

Run: `fvm flutter test test/shared/widgets/add_to_playlist_dialog_test.dart`

Expected: FAIL because the add-to-playlist dialog has no creation action.

**Step 3: Implement reuse**

Add a tonal icon button above the destination list and call `showCreatePlaylistDialog(context)`. Replace Home's private dialog body with the same helper.

**Step 4: Run focused and repository checks**

Run:

```bash
fvm dart format lib/shared/widgets/create_playlist_dialog.dart lib/shared/widgets/add_to_playlist_dialog.dart lib/features/home/home_page.dart test/shared/widgets/create_playlist_dialog_test.dart test/shared/widgets/add_to_playlist_dialog_test.dart
fvm flutter test test/shared/widgets/create_playlist_dialog_test.dart test/shared/widgets/add_to_playlist_dialog_test.dart
fvm flutter test
fvm flutter analyze
git diff --check
```

Expected: formatting is unchanged after the first pass, tests pass, analyzer reports no issues, and the diff has no whitespace errors.
