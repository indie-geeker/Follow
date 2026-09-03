# Username or Email Login Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Support username-or-email plus password login in the API, web administration client, and Flutter client.

**Architecture:** Replace the login request's email-only field with a required identifier field, normalize it through the shared credential policy, and query the existing unique username/email columns. Update both clients and their remembered-account stores to use the same identifier contract while leaving registration, sessions, and token transports unchanged.

**Tech Stack:** .NET 10, EF Core/PostgreSQL, xUnit, Vue 3/TypeScript/Pinia/Element Plus, Node test runner, Flutter/Riverpod/Dio/SharedPreferences.

---

### Task 1: Define and prove the server login contract

**Files:**
- Modify: `follow-server/src/Follow.Shared/DTOs/AuthDtos.cs`
- Modify: `follow-server/src/Follow.Core/Services/UserCredentialPolicy.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/AuthService.cs`
- Test: `follow-server/tests/Follow.Core.Tests/UserCredentialPolicyTests.cs`
- Test: `follow-server/tests/Follow.Api.Tests/AuthSessionServiceTests.cs`
- Test: `follow-server/tests/Follow.Api.Tests/AuthEndpointContractTests.cs`

**Steps:**
1. Add a failing credential-policy test for NFKC, trim, and lowercase login identifier normalization.
2. Run the focused Core test and confirm it fails because the normalizer does not exist.
3. Add the minimal normalizer and rerun the focused test to green.
4. Replace service login fixtures with `Identifier` and add failing tests for username login, email login, normalized input, wrong password, and unknown identifier.
5. Run focused API tests and confirm failure because login still queries email only.
6. Replace `LoginRequest.Email` with `Identifier` and implement one username-or-email query.
7. Rerun the focused tests, then the two .NET test projects.

### Task 2: Update the web login and remembered-account contract

**Files:**
- Modify: `follow-admin/src/stores/auth.ts`
- Modify: `follow-admin/src/views/auth/LoginView.vue`
- Modify: `follow-admin/src/utils/rememberedAccount.ts`
- Test: `follow-admin/tests/authSession.test.ts`
- Test: `follow-admin/tests/rememberedAccount.test.ts`

**Steps:**
1. Add failing tests that require the login payload to contain `identifier` and omit `email`.
2. Add failing remembered-account tests for `{ identifier }` persistence and migration from both current `{ email }` and legacy credential shapes.
3. Run `npm test -- --runInBand` if supported by the package scripts, otherwise the repository's existing test command, and confirm the focused failures.
4. Implement identifier naming, non-empty validation, `用户名或邮箱` UI copy, and remembered-identifier persistence.
5. Rerun the focused tests and the full web test suite.
6. Run the web TypeScript/production build.

### Task 3: Update the Flutter login and remembered-account contract

**Files:**
- Modify: `follow/lib/data/models/user.dart`
- Modify: `follow/lib/data/services/api/api_service.dart`
- Modify: `follow/lib/data/services/auth/auth_repository.dart`
- Modify: `follow/lib/data/providers/auth_provider.dart`
- Modify: `follow/lib/data/services/auth/remembered_email_store.dart`
- Modify: `follow/lib/features/auth/login_page.dart`
- Test: `follow/test/data/models/auth_contract_test.dart`
- Test: `follow/test/data/services/auth/auth_repository_test.dart`
- Test: `follow/test/data/services/auth/remembered_email_store_test.dart`
- Test: add or update the focused login-page widget/source contract test located during implementation.

**Steps:**
1. Add failing JSON-contract and repository tests requiring `identifier` forwarding and no login `email` field.
2. Add failing remembered-store tests for identifier persistence and migration from existing email keys while continuing to delete password/token legacy keys.
3. Add a failing login-page test for the `用户名或邮箱` label, non-email keyboard/validation, and remembered identifier flow.
4. Run focused Flutter tests with the checkout's configured Flutter SDK and `--no-pub`; confirm each fails for the missing contract.
5. Implement the minimal model, repository, provider, store, and page changes.
6. Rerun focused tests and scoped formatting/analyze checks.

### Task 4: Cross-client verification

**Files:**
- Modify if needed: `follow-server/README.md`
- Modify if needed: `follow-admin/README.md`
- Modify if needed: `follow/README.md`

**Steps:**
1. Update only current authentication documentation that still promises email-only login or remembered-email behavior.
2. Run all `Follow.Core.Tests` and `Follow.Api.Tests`.
3. Run all admin tests and the production build.
4. Run all Flutter tests with `--no-pub` and scoped/full analyze as supported by the current SDK configuration.
5. Run `git diff --check` and inspect the scoped diff plus repository status.
6. Report implementation, tests/builds, and unverified runtime/device/deployment boundaries separately; do not commit, push, or deploy.
