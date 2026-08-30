# Follow Admin UI Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for each behavior change and superpowers:verification-before-completion before reporting success.

**Goal:** Fix optional album-year rendering and make the admin UI safer, responsive, accessible, visually consistent, and lighter without changing its product structure.

**Architecture:** Keep shared UI behavior in small utilities/components, keep page data flows local, and replace runtime-generated animation styles with deterministic CSS. Register only the Element Plus components actually used by the admin app, while preserving service APIs such as `ElMessage` and `ElMessageBox`.

**Tech Stack:** Vue 3, TypeScript, Element Plus, Pinia, Vue Router, Vite, Node test runner.

**Repository safety:** The worktree already contains user changes. Do not reset, stash, broadly stage, commit, or modify unrelated files.

---

### Task 1: Lock down expected UI behavior with failing tests

**Files:**
- Modify: `follow-admin/tests/adminUiConsistency.test.ts`
- Create: `follow-admin/tests/rememberedAccount.test.ts`
- Create: `follow-admin/tests/optionalValues.test.ts`

**Steps:**
1. Add assertions for an em dash fallback for missing album years and preservation of optional year values.
2. Add in-memory-storage tests proving legacy password data is removed and only an email address can be persisted.
3. Add source-level regressions for mobile navigation, reduced motion, accessible play controls, and removal of runtime-generated style tags.
4. Run the focused tests and confirm the new assertions fail for the intended reasons.

### Task 2: Fix optional album years

**Files:**
- Create: `follow-admin/src/utils/display.ts`
- Modify: `follow-admin/src/views/music/AlbumsView.vue`

**Steps:**
1. Implement a reusable optional-value formatter.
2. Render a subdued em dash instead of an empty `el-tag` when the year is absent.
3. Preserve a missing year when editing and submit it as `null` instead of replacing it with the current year.
4. Add explicit loading failure and empty-table feedback.
5. Run the focused tests.

### Task 3: Stop storing passwords in browser storage

**Files:**
- Create: `follow-admin/src/utils/rememberedAccount.ts`
- Modify: `follow-admin/src/views/LoginView.vue`

**Steps:**
1. Implement load/save helpers that persist only a normalized email address.
2. Migrate and immediately delete the legacy `savedCredentials` entry, including its password.
3. Change the UI copy from remembering credentials to remembering the account.
4. Replace login-page runtime style injection with deterministic CSS animation.
5. Run the focused tests.

### Task 4: Make the admin shell responsive and motion-safe

**Files:**
- Modify: `follow-admin/src/layouts/AdminLayout.vue`
- Modify: `follow-admin/src/components/AdminPagination.vue`
- Create: `follow-admin/src/styles/admin-components.css`

**Steps:**
1. Add a 72px tablet sidebar and an off-canvas mobile drawer with backdrop, Escape handling, route-close behavior, and accessible menu controls.
2. Remove runtime-generated sidebar animation styles and replace them with fixed CSS keyframes.
3. Make pagination compact on mobile and increase interaction target sizes.
4. Add shared action-target sizing and `prefers-reduced-motion` handling.
5. Run the focused tests.

### Task 5: Improve page feedback and control accessibility

**Files:**
- Modify: `follow-admin/src/views/music/TracksView.vue`
- Modify: `follow-admin/src/views/music/ArtistsView.vue`
- Modify: `follow-admin/src/views/music/TagsView.vue`
- Modify: `follow-admin/src/views/users/UsersView.vue`

**Steps:**
1. Add meaningful empty-state labels to data tables.
2. Add accessible names to icon-only controls.
3. Add missing load-error feedback without changing existing request contracts.
4. Run the focused tests.

### Task 6: Centralize tokens and reduce Element Plus payload

**Files:**
- Create: `follow-admin/src/styles/tokens.css`
- Create: `follow-admin/src/plugins/elementPlus.ts`
- Modify: `follow-admin/src/styles/theme.css`
- Modify: `follow-admin/src/main.ts`
- Modify: `follow-admin/src/App.vue`

**Steps:**
1. Move shared color and spacing variables into a directly imported token file.
2. Register only the Element Plus components/directives used by the app and import their component styles.
3. Keep message/dialog service styles available.
4. Use a stable multilingual application font stack.
5. Run the full test suite and production build; compare bundle output with the previous full-library baseline.

### Task 7: Verify the real user workflow

**Files:**
- Verify only; no additional files expected.

**Steps:**
1. Run all admin tests and a clean production build.
2. Start the existing Docker development stack without recreating persistent data.
3. Verify desktop, tablet, and mobile navigation; user/track pagination consistency; album empty-year rendering; login storage migration; and console/network health in a real browser.
4. Run `git diff --check` and inspect the final scoped diff.
