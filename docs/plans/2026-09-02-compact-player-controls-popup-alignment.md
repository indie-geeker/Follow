# Compact Player Controls Popup Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Compact the mobile player controls so the playback-mode popup is strictly centered over its button on a 360px viewport without clipping.

**Architecture:** Replace the layered `Stack` control layout with one fixed-width symmetric `Row`. Keep standard controls at 48px, reduce the primary play control to 56px, and use 4px gaps to produce a 264px row whose left control center naturally aligns with the 128px popup.

**Tech Stack:** Flutter, Riverpod, flutter_test.

---

### Task 1: Define compact alignment behavior

**Files:**
- Modify: `follow/test/shared/widgets/player/player_main_controls_test.dart`

**Step 1: Write the failing test**

- Set the logical viewport to 360×800.
- Open the playback-mode popup through `PlayerMainControls`.
- Assert the popup center matches the mode-button center within 1px and its left edge is at least 8px.
- Assert ordinary controls are 48×48, the play control is 56×56, and the play button stays centered.

**Step 2: Run the test to verify it fails**

Run: `fvm flutter test --no-pub test/shared/widgets/player/player_main_controls_test.dart`

Expected: FAIL because the current mode button stays near the edge and the popup requires a horizontal correction.

### Task 2: Implement the compact symmetric row

**Files:**
- Modify: `follow/lib/shared/widgets/player/player_main_controls.dart`

**Step 1: Write the minimal implementation**

- Replace the current `Stack` with a centered `Row`.
- Use 24px icons for mode, previous, next and queue controls, retaining their 12px padding and 48px touch areas.
- Set the play control to 56×56 with a 30px icon.
- Use 4px between every adjacent control.

**Step 2: Run focused tests**

Run: `fvm flutter test --no-pub test/shared/widgets/player/player_main_controls_test.dart test/shared/widgets/player/player_mode_control_test.dart`

Expected: PASS.

### Task 3: Verify player behavior

**Files:**
- Verify all files above.

**Step 1: Analyze scoped files**

Run: `fvm flutter analyze --no-pub lib/shared/widgets/player/player_main_controls.dart test/shared/widgets/player/player_main_controls_test.dart`

Expected: No issues found.

**Step 2: Run player tests**

Run: `fvm flutter test --no-pub test/shared/widgets/player test/features/player/interactive_lyrics_integration_test.dart`

Expected: PASS.

**Step 3: Run full Flutter tests and diff checks**

Run: `fvm flutter test --no-pub && git diff --check`

Expected: PASS. Confirm `follow/pubspec.lock` remains unchanged; do not commit, push or deploy.
