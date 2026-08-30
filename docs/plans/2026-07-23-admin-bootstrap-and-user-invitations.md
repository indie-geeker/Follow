# Admin Bootstrap and User Invitations Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Replace first-user admin promotion with an environment-configured administrator, enforce canonical user credentials, and let authenticated administrators create or invite users from the web console.

**Architecture:** Centralize username, email, and password rules in the Core project so bootstrap, self-registration, and admin-created users share one contract. Seed the configured administrator after EF migrations and before the API accepts traffic. Add an Admin-only create-user endpoint and a focused Element Plus dialog that creates accounts with a generated or entered temporary password.

**Tech Stack:** .NET 10 minimal APIs, EF Core/PostgreSQL, xUnit, Vue 3, TypeScript, Element Plus, Docker Compose, Flutter.

---

### Task 1: Shared user credential policy

**Files:**
- Create: `follow-server/src/Follow.Core/Services/UserCredentialPolicy.cs`
- Create: `follow-server/tests/Follow.Core.Tests/UserCredentialPolicyTests.cs`
- Modify: `follow-server/tests/Follow.Core.Tests/Follow.Core.Tests.csproj`

**Steps:**
1. Add failing tests for NFKC/trim/lowercase username and email normalization.
2. Add failing tests for username length/character rules and password length/complexity rules.
3. Run `dotnet test tests/Follow.Core.Tests/Follow.Core.Tests.csproj` and confirm failures are caused by the missing policy.
4. Implement the minimal shared policy and rerun the tests to green.

### Task 2: Registration roles and admin-created users

**Files:**
- Modify: `follow-server/src/Follow.Infrastructure/Services/AuthService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/AdminService.cs`
- Modify: `follow-server/src/Follow.Core/Interfaces/IAdminService.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/AdminEndpoints.cs`
- Modify: `follow-server/src/Follow.Shared/DTOs/AuthDtos.cs`
- Create: `follow-server/tests/Follow.Api.Tests/UserAccountServiceTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj`

**Steps:**
1. Add failing service tests proving public registration always creates `Member`, credentials are normalized, and invalid input is rejected.
2. Add failing tests proving admin-created accounts honor `Member`/`Admin` role and reject duplicates.
3. Implement shared policy use in `AuthService`, `AdminService`, and `POST /api/admin/users`.
4. Run both test projects and keep them green.

### Task 3: Environment-configured administrator

**Files:**
- Create: `follow-server/src/Follow.Infrastructure/Services/AdminAccountInitializer.cs`
- Modify: `follow-server/src/Follow.Api/Program.cs`
- Modify: `docker-compose.yml`
- Modify: `follow-server/docker-compose.yml`
- Modify: `.env.example`
- Modify: `.env`
- Modify: `scripts/verify-docker-config.sh`

**Steps:**
1. Add failing tests for creating the configured administrator and idempotently maintaining it as Admin.
2. Implement `AdminAccount` configuration validation and startup initialization after migrations.
3. Inject `ADMIN_USERNAME`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD` through both Compose files.
4. Add safe local values to ignored `.env` and placeholders to `.env.example`.
5. Extend Docker configuration checks and run them to green.

### Task 4: Web admin create/invite workflow

**Files:**
- Modify: `follow-admin/src/views/users/UsersView.vue`

**Steps:**
1. Add an “邀请用户” primary action and an accessible Element Plus dialog.
2. Collect username, email, role, and temporary password; mirror server validation messages.
3. Generate a strong temporary password with Web Crypto and allow copying it.
4. Submit to `POST /api/admin/users`, show actionable failures, close on success, and refresh the list.
5. Run `pnpm run build`.

### Task 5: Cross-client contract and documentation

**Files:**
- Modify: `follow/lib/features/auth/login_page.dart`
- Modify: `follow-server/README.md`
- Modify: `follow-admin/README.md`
- Modify: `follow-server/docs/deployment-guide.md`

**Steps:**
1. Align Flutter registration validation with the server contract.
2. Document environment administrator behavior and admin invitation workflow.
3. Document that the configured admin password is authoritative on API restart.

### Task 6: Full verification

**Steps:**
1. Run all .NET tests and build the solution.
2. Run the admin production build and Flutter static analysis for affected code.
3. Run Docker configuration checks and `git diff --check`.
4. Rebuild the API/admin containers and verify PostgreSQL, MinIO, Redis, API health, configured admin login, ordinary registration as Member, and authenticated admin user creation.
5. Report exactly what ran and preserve unrelated dirty-tree changes; do not commit or stage without explicit authorization.
