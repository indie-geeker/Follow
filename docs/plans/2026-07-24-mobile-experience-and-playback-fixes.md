# Follow Mobile Experience and Playback Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development and superpowers:verification-before-completion to implement this plan task-by-task.

**Goal:** Repair the reported Android runtime failures and turn the primary mobile music flow into a safe-area-aware, coherent, polished experience.

**Architecture:** Keep search as a secondary route launched from Library while reducing the main shell to four destinations. Centralize mobile surface/header styling and platform capability decisions so Home, Library, Downloads, Search, Settings, and the bottom player follow one contract. On Android, send authorization headers natively so no local cleartext proxy is needed; permit only the emulator API host in debug/profile while desktop-only folder actions are guarded in both UI and provider layers.

**Tech Stack:** Flutter 3.41, Material 3, Riverpod 3, auto_route 10, just_audio, Android Network Security Config, flutter_test.

**Working-tree note:** This checkout already contains unrelated user changes. Do not create a worktree, commit, stage, reset, or edit `follow/lib/core/config/app_config.dart` / `follow/pubspec.lock`; keep this patch limited to the files named below.

---

### Task 1: Pin the requested behavior with failing tests

**Files:**
- Create: `follow/test/shared/widgets/empty_state_card_test.dart`
- Create: `follow/test/core/platform/platform_capabilities_test.dart`
- Create: `follow/test/router/mobile_navigation_spec_test.dart`
- Create: `follow/test/android/android_network_security_test.dart`

**Step 1: Write failing tests**

- Assert an empty-state action renders as a 48dp-or-larger semantic button and invokes its callback.
- Assert native folder browsing is supported only on macOS, Windows, and Linux—not Android/iOS.
- Assert the mobile navigation specification contains exactly Home, Library, Downloads, and Settings.
- Assert the main Android manifest contains `INTERNET` and a network-security config, the release config permits only loopback cleartext, and debug/profile overlays permit the emulator API host.

**Step 2: Run tests to verify RED**

Run: `fvm flutter test test/shared/widgets/empty_state_card_test.dart test/core/platform/platform_capabilities_test.dart test/router/mobile_navigation_spec_test.dart test/android/android_network_security_test.dart`

Expected: FAIL because the action API, capability policy, four-item navigation spec, and Android XML contract do not exist yet.

### Task 2: Introduce the shared mobile visual and navigation contract

**Files:**
- Create: `follow/lib/core/platform/platform_capabilities.dart`
- Create: `follow/lib/router/mobile_navigation.dart`
- Create: `follow/lib/shared/widgets/app_page_surface.dart`
- Modify: `follow/lib/core/theme/app_theme.dart`
- Modify: `follow/lib/router/app_router.dart`
- Modify: `follow/lib/features/home/home_page.dart`
- Modify: `follow/lib/shared/widgets/mini_player.dart`

**Step 1: Implement the minimum policy objects**

- Add `supportsNativeFolderBrowsing(TargetPlatform)` with desktop-only results.
- Add a typed four-item `mobileNavigationDestinations` list used by the shell.
- Add a reusable full-screen surface that paints the restrained branded background while allowing a `SafeArea` content layer.

**Step 2: Fix shell and safe-area behavior**

- Remove Search from both mobile and desktop primary navigation.
- Move `SearchRoute` to a guarded secondary route at `/search`.
- Place the bottom player/navigation stack inside a bottom `SafeArea`.
- Keep Home's pinned tab strip below the top system inset for the entire scroll lifecycle.
- Simplify the mobile mini-player to the essential play/pause and next controls, and implement Next.

**Step 3: Re-run targeted tests**

Expected: platform and navigation tests PASS.

### Task 3: Make empty history and Library search form one guided flow

**Files:**
- Modify: `follow/lib/shared/widgets/empty_state_card.dart`
- Modify: `follow/lib/features/home/views/recently_played_view.dart`
- Modify: `follow/lib/features/home/home_page.dart`
- Modify: `follow/lib/features/library/library_page.dart`
- Modify: `follow/lib/features/library/widgets/library_search_box.dart`
- Modify: `follow/lib/features/search/search_page.dart`

**Step 1: Implement the tested empty-state action**

- Add optional `actionLabel`, `actionIcon`, and `onAction` fields to `EmptyStateCard`.
- Render a semantic `FilledButton.icon` with a minimum 48dp touch target.
- In Recently Played, label the action `进入音乐库` and switch to the Library tab.

**Step 2: Consolidate search UX**

- On phones, show one 48dp Library search button that pushes `/search`.
- On larger layouts, retain the inline library search field.
- Add a back button and autofocus to the secondary Search page, preserve query state, and remove copy that implies a duplicate primary destination.

**Step 3: Verify RED to GREEN**

Run the empty-state widget test, then the full Flutter test suite.

### Task 4: Guard desktop-only folders and complete downloaded playback

**Files:**
- Modify: `follow/lib/data/providers/download_provider.dart`
- Modify: `follow/lib/features/downloads/downloads_page.dart`
- Modify: `follow/lib/features/settings/settings_page.dart`

**Step 1: Apply defense in depth**

- Hide folder-open/reveal and folder-picker controls on Android/iOS.
- Guard provider methods before invoking plugins and catch `MissingPluginException` as an unsupported capability, returning `false` rather than throwing.
- Describe mobile storage as app-managed instead of exposing an unusable private path.

**Step 2: Repair the adjacent broken interaction**

- Make downloaded rows play their local file through `playAll(tracks, startIndex: index)`.
- Keep desktop reveal actions at least 48dp and give them tooltips.

**Step 3: Run capability and widget tests**

Expected: Android/iOS capability tests PASS and no mobile UI invokes `open_dir`.

### Task 5: Allow local Android playback without weakening release transport policy

**Files:**
- Modify: `follow/android/app/src/main/AndroidManifest.xml`
- Create: `follow/android/app/src/main/res/xml/network_security_config.xml`
- Create: `follow/android/app/src/debug/res/xml/network_security_config.xml`
- Create: `follow/android/app/src/profile/res/xml/network_security_config.xml`

**Step 1: Implement the manifest contract**

- Add `android.permission.INTERNET` to the main manifest.
- Reference `@xml/network_security_config` from the application.
- Configure `just_audio` to use Android's native request-header support instead of its localhost HTTP proxy.
- Reject every cleartext host in release.
- Overlay debug/profile configs to permit only `10.0.2.2`, the checked-in local Android API default.

**Step 2: Verify Android configuration**

Run the Android XML contract test, then `./gradlew :app:processDebugMainManifest` from `follow/android`.

Expected: tests PASS and manifest merge exits 0.

### Task 6: Final quality gate

**Files:**
- Modify only formatting/generator outputs required by the files above; generated `*.g.dart` and `*.gr.dart` remain ignored.

**Step 1: Regenerate and format**

Run: `fvm dart run build_runner build --delete-conflicting-outputs`

Run: `fvm dart format lib test`

**Step 2: Run fresh verification**

Run: `fvm flutter analyze`

Run: `fvm flutter test`

Run: `fvm flutter build apk --debug`

Run: `git diff --check`

**Step 3: Review scope**

- Confirm unrelated dirty files are untouched.
- Confirm the six user requests against the final diff.
- Report automated evidence separately from emulator/device proof; do not claim real playback or plugin behavior without a device run.
