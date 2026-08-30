# Music Library Initialization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an opt-in, restart-safe server-side music-library initialization workflow that scans a read-only mounted directory, imports files into MinIO and PostgreSQL idempotently, and exposes an admin task UI without running a real music import during implementation.

**Architecture:** PostgreSQL stores durable `MusicImportBatch` and `MusicImportItem` state. A hosted worker scans a configured root, leases one item at a time, hashes and validates it, writes a deterministic MinIO object, and commits Track plus item terminal state in one database transaction. The feature is disabled by default; a separate Compose overlay mounts a user-selected source directory read-only when the user later validates it manually.

**Tech Stack:** .NET 10 minimal APIs, EF Core/Npgsql, TagLibSharp, MinIO .NET SDK, PostgreSQL, Vue 3, TypeScript, Element Plus, Node test runner, Docker Compose.

---

## Repository safety constraints

- Work in the current checkout because it already contains substantial user-owned changes; do not create a worktree, reset files, or restore from `HEAD`.
- Do not stage, commit, push, or create a PR. Use scoped diffs only.
- Do not mount a real music directory, start Docker containers, call the import endpoints against a live API, or upload any media.
- Automated tests may use small temporary text/binary fixtures and fake storage/metadata readers only.
- Add a new migration after `20260727011941_RemoveRssAddSessionsAndStorageOutbox`; never edit that existing untracked migration.
- The existing migration includes destructive RSS removal. Do not apply migrations to a live database in this implementation turn.
- The base Compose stack must remain free of host media mounts. The import mount belongs only in `docker-compose.import.yml`.

### Task 1: Pure import policies and state machine

**Files:**
- Create: `follow-server/src/Follow.Core/Entities/MusicImportStatus.cs`
- Create: `follow-server/src/Follow.Core/Services/MusicImportStateMachine.cs`
- Create: `follow-server/src/Follow.Core/Services/MusicImportPathPolicy.cs`
- Create: `follow-server/src/Follow.Core/Services/AudioFilePolicy.cs`
- Create: `follow-server/tests/Follow.Core.Tests/MusicImportStateMachineTests.cs`
- Create: `follow-server/tests/Follow.Core.Tests/MusicImportPathPolicyTests.cs`
- Create: `follow-server/tests/Follow.Core.Tests/AudioFilePolicyTests.cs`

**Step 1: Write failing state-transition tests**

Cover batch transitions `Pending -> Scanning -> Ready -> Running -> Verifying -> Completed`, pause/resume/cancel, and rejection of invalid terminal-state transitions. Cover item terminal states and retry eligibility.

**Step 2: Run RED state tests**

Run: `dotnet test tests/Follow.Core.Tests/Follow.Core.Tests.csproj --filter MusicImportStateMachineTests`

Expected: FAIL because the state machine and enums do not exist.

**Step 3: Implement the minimal state machine**

Use explicit enum values and pure `CanTransition`/`EnsureTransition` functions. No EF or host dependencies.

**Step 4: Write and run RED path/audio-policy tests**

Cover empty/absolute/parent traversal/backslash/control-character paths, root-prefix siblings, supported case-insensitive extensions, zero-byte files, and configured maximum path length.

Run: `dotnet test tests/Follow.Core.Tests/Follow.Core.Tests.csproj --filter "MusicImportPathPolicyTests|AudioFilePolicyTests"`

Expected: FAIL because the policies do not exist.

**Step 5: Implement and verify GREEN**

Resolve only relative paths under the configured root, normalize stored separators to `/`, reject symlinks/reparse points during scanning, and centralize `.mp3/.flac/.wav/.aac/.ogg/.m4a` plus canonical MIME mapping.

Run: `dotnet test tests/Follow.Core.Tests/Follow.Core.Tests.csproj`

Expected: PASS with no failures.

**Step 6: Scoped diff check**

Run: `git diff --check -- follow-server/src/Follow.Core follow-server/tests/Follow.Core.Tests`

Expected: no output. Do not commit.

### Task 2: Durable schema and API contracts

**Files:**
- Create: `follow-server/src/Follow.Core/Entities/MusicImportBatch.cs`
- Create: `follow-server/src/Follow.Core/Entities/MusicImportItem.cs`
- Modify: `follow-server/src/Follow.Core/Entities/Track.cs`
- Create: `follow-server/src/Follow.Core/Interfaces/IMusicImportService.cs`
- Create: `follow-server/src/Follow.Core/Interfaces/IAudioMetadataExtractor.cs`
- Create: `follow-server/src/Follow.Shared/DTOs/MusicImportDtos.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Data/FollowDbContext.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportModelContractTests.cs`

**Step 1: Write failing EF model tests**

Assert:

- `MusicImportBatch` and `MusicImportItem` are in the model.
- `(RequestedByUserId, ClientRequestId)` and `(BatchId, RelativePath)` are unique.
- item claim/status indexes exist.
- `Track.ContentSha256` is nullable and has a filtered unique index.
- enums persist as strings and error/path lengths are bounded.

**Step 2: Run RED model tests**

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter MusicImportModelContractTests`

Expected: FAIL because the entities/model contract do not exist.

**Step 3: Implement minimal entities, DTOs, and model configuration**

Keep new Track fields nullable so existing initializers and old rows remain valid. Store audit data on items: relative path, size, mtime, SHA-256, status/stage, attempts, lease, object path, TrackId, error code/message, timestamps.

**Step 4: Verify GREEN and all API tests**

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter MusicImportModelContractTests`

Expected: PASS.

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj`

Expected: PASS with no failures.

**Step 5: Scoped diff check**

Run: `git diff --check -- follow-server/src/Follow.Core follow-server/src/Follow.Shared follow-server/src/Follow.Infrastructure/Data follow-server/tests/Follow.Api.Tests`

Expected: no output. Do not commit.

### Task 3: Safe scanner and batch control service

**Files:**
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportScanner.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportService.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportScannerTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportServiceTests.cs`

**Step 1: Write failing scanner tests**

Use a small temporary directory. Verify recursive discovery, ignored non-audio files, normalized relative paths, size/mtime capture, restart-safe duplicate suppression, cancellation, and refusal of symlink/reparse-point entries. Do not create real audio content.

**Step 2: Run RED scanner tests**

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter MusicImportScannerTests`

Expected: FAIL because the scanner does not exist.

**Step 3: Implement streaming scan**

Enumerate without following reparse points, save in bounded chunks, and derive totals from durable items so a restarted scan does not double-count.

**Step 4: Write RED batch-control tests**

Verify idempotent create by `ClientRequestId`, start only from Ready, pause/resume/cancel semantics, retry only retryable failures, paginated item retrieval, and disabled-feature behavior.

**Step 5: Implement service and verify GREEN**

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter "MusicImportScannerTests|MusicImportServiceTests"`

Expected: PASS.

### Task 4: Idempotent per-file processor and deterministic storage write

**Files:**
- Modify: `follow-server/src/Follow.Core/Interfaces/IStorageService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/MinioStorageService.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/TagLibAudioMetadataExtractor.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportProcessor.cs`
- Modify storage fakes in:
  - `follow-server/tests/Follow.Api.Tests/ServiceFactory.cs`
  - `follow-server/tests/Follow.Api.Tests/StorageDeletionWorkerTests.cs`
  - `follow-server/tests/Follow.Api.Tests/TrackStorageConsistencyTests.cs`
  - `follow-server/tests/Follow.Api.Tests/TrackStreamingTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportProcessorTests.cs`

**Step 1: Write failing processor behavior tests**

Use a real tiny temporary source file, a fake metadata extractor returning a complete metadata record, and an in-memory recording storage implementation. Verify:

- SHA-256 exact duplicate links the existing Track and writes no object.
- a new item writes to `tracks/import/{itemId}/audio.<ext>` and creates one Track.
- database failure leaves the item retryable and schedules/executes safe object cleanup.
- source size/mtime changes fail with `SOURCE_CHANGED`.
- invalid metadata fails before storage.

Assertions must target database/item/object outcomes, not mock call existence.

**Step 2: Run RED processor tests**

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter MusicImportProcessorTests`

Expected: FAIL because the processor/storage method do not exist.

**Step 3: Add deterministic storage API and implementation**

Keep the existing upload method intact. Add an internal-facing object-key write with cancellation; validate that keys are relative, managed, and under `tracks/import/`. Never expose MinIO credentials or a public presigned surface.

**Step 4: Implement processor**

Hash first, validate TagLib metadata, upload one stream without a second full temporary copy, and commit Track plus item terminal state together. Default processing concurrency remains one until a real PostgreSQL concurrency gate is executed.

**Step 5: Verify GREEN and storage regressions**

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter "MusicImportProcessorTests|TrackStorageConsistencyTests|StorageDeletionWorkerTests"`

Expected: PASS.

### Task 5: Restart-safe worker, admin endpoints, disabled-by-default configuration, and migration

**Files:**
- Create: `follow-server/src/Follow.Api/Configuration/MusicImportOptions.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportWorker.cs`
- Create: `follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs`
- Modify: `follow-server/src/Follow.Api/Program.cs`
- Modify: `follow-server/src/Follow.Api/appsettings.json`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportWorkerTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportEndpointContractTests.cs`
- Create: a new timestamped migration after `20260727011941_RemoveRssAddSessionsAndStorageOutbox`
- Modify via EF tooling: `follow-server/src/Follow.Infrastructure/Data/Migrations/FollowDbContextModelSnapshot.cs`

**Step 1: Write failing worker tests**

Test one exposed iteration method: pending batch scans, Ready waits for explicit start, Running claims one item, expired processing work becomes retryable, pause/cancel stops new claims, and terminal counts move a batch into Verifying/CompletedWithErrors.

**Step 2: Run RED worker tests**

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter MusicImportWorkerTests`

Expected: FAIL because the worker does not exist.

**Step 3: Implement worker and configuration**

`MusicImport.Enabled` defaults false. Register services and the hosted worker without changing the existing auth/rate/authorization/migration/admin-initializer order. The worker must not touch the filesystem while disabled.

**Step 4: Write RED endpoint contract tests**

Assert all routes are under `/api/admin/music-imports`, use `AdminOnly`, return relative/audited data only, and support create/list/detail/items/start/pause/resume/cancel/retry-failures/capabilities.

**Step 5: Implement endpoints and verify GREEN**

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter "MusicImportWorkerTests|MusicImportEndpointContractTests"`

Expected: PASS.

**Step 6: Generate a separate migration**

Run from `follow-server`:

`dotnet ef migrations add AddMusicLibraryInitialization --project src/Follow.Infrastructure --startup-project src/Follow.Api`

Expected: one new migration pair plus snapshot changes. Do not update or connect to a database.

**Step 7: Inspect migration**

Confirm it only adds MusicImport tables/indexes and nullable Track import fields. It must not edit the prior RSS/session/outbox migration and must not scan files or hash data.

### Task 6: Admin import task UI

**Files:**
- Create: `follow-admin/src/types/musicImport.ts`
- Create: `follow-admin/src/api/musicImports.ts`
- Create: `follow-admin/src/views/music/imports/MusicImportListView.vue`
- Create: `follow-admin/src/views/music/imports/MusicImportCreateView.vue`
- Create: `follow-admin/src/views/music/imports/MusicImportDetailView.vue`
- Modify narrowly: `follow-admin/src/router/index.ts`
- Modify narrowly: `follow-admin/src/layouts/AdminLayout.vue`
- Modify narrowly: `follow-admin/src/views/music/TracksView.vue`
- Create: `follow-admin/tests/musicImportUiContract.test.ts`
- Create: `follow-admin/tests/musicImportApi.test.ts`

**Step 1: Write RED admin contract tests**

Assert:

- routes `/tracks/imports`, `/tracks/imports/new`, and `/tracks/imports/:jobId` exist;
- they keep `/tracks` active and carry dynamic page titles;
- Tracks has an initialization entry without altering single-file upload;
- API calls remain same-origin and use the shared cookie client;
- create uses `crypto.randomUUID()` as `clientRequestId`;
- detail polls status, paginates items, and exposes valid state actions;
- the UI explicitly says the source directory is server-mounted and read-only.

**Step 2: Run RED admin tests**

Run: `pnpm test -- --test-name-pattern="music import"`

Expected: FAIL because the files/routes do not exist.

**Step 3: Implement typed API and pages**

Use only currently registered Element Plus components and native `<progress>`; do not add packages or modify the lockfile. Server data is the source of truth; no Pinia import store and no browser `File` objects.

**Step 4: Verify GREEN and build**

Run: `pnpm test`

Expected: PASS.

Run: `pnpm run build`

Expected: exit 0.

### Task 7: Explicit opt-in Compose overlay and operational documentation

**Files:**
- Create: `docker-compose.import.yml`
- Modify narrowly: `.env.example`
- Modify: `scripts/verify-docker-config.sh`
- Modify narrowly: `follow-server/README.md`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportConfigurationTests.cs`

**Step 1: Write RED configuration tests**

Assert safe defaults: disabled in base appsettings, no import bind in base Compose, opt-in overlay requires `FOLLOW_IMPORT_SOURCE_PATH`, target is `/imports/library`, long bind syntax sets `read_only: true` and `bind.create_host_path: false`.

**Step 2: Run RED configuration tests**

Run: `dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter MusicImportConfigurationTests`

Expected: FAIL because the overlay/config contract does not exist.

**Step 3: Implement overlay and docs**

Document only future manual validation commands. Do not execute them. Explain that cancel preserves imported tracks, source files are never modified, and post-import idempotency is required before removing the mount.

**Step 4: Verify static Compose contracts only**

Run: `bash scripts/verify-docker-config.sh`

Expected: base and overlay configuration checks pass without starting containers.

### Task 8: Final verification and review

**Step 1: Re-read this plan and inspect scoped diff**

Run: `git status --short`

Run: `git diff --stat -- follow-server follow-admin docker-compose.import.yml .env.example scripts/verify-docker-config.sh docs/plans/2026-07-27-music-library-initialization.md`

Confirm unrelated user files remain untouched.

**Step 2: Run complete automated gates**

Run from `follow-server`: `dotnet test Follow.slnx`

Run from `follow-admin`: `pnpm test`

Run from `follow-admin`: `pnpm run build`

Run from repository root: `bash scripts/verify-docker-config.sh`

Run from repository root: `git diff --check`

**Step 3: Perform source-level safety review**

Verify:

- disabled configuration causes zero source-directory access;
- no host absolute path appears in API responses/logs;
- no real import, MinIO write, Docker startup, migration apply, or media upload was executed;
- deterministic object paths remain under `tracks/import/`;
- cancellation never deletes already imported Tracks;
- the UI does not promise that a browser uploads or watches the folder;
- the migration is additive relative to the current working model.

**Step 4: Report evidence and manual validation boundary**

Report exact test/build counts and explicitly state that real mounted-directory scan, TagLib parsing of real audio, MinIO write, PostgreSQL migration application, restart recovery against real services, and playback remain for the user's later manual validation.
