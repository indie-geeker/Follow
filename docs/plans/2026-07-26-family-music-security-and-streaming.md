# Family Music Security and Streaming Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Follow 收敛为安全、可长期运行的家庭音乐应用：删除 RSS，完成多设备会话与安全令牌、同源 HTTPS、私有 MinIO、Range 流媒体、对象补偿清理、歌单所有权和稳定分页。

**Architecture:** 外部访问只经过 Caddy HTTPS 网关；管理后台与 `/api` 同源，Web 使用 HttpOnly Cookie，Flutter 使用系统安全存储。服务端以 `UserSession` 保存 Refresh Token 哈希并在 JWT 中携带 `sid`；MinIO 只在 Docker 内网开放，API 按 HTTP Range 直接代理对象片段。PostgreSQL 与 MinIO 的跨资源一致性采用数据库事务加 `StorageDeletionJob` outbox，而不是假设分布式事务。

**Tech Stack:** .NET 10 Minimal API、EF Core 10/PostgreSQL、MinIO .NET 7、ASP.NET Core Rate Limiting、Vue 3/Pinia/Axios、Flutter/Riverpod/Dio/flutter_secure_storage、Docker Compose/Caddy。

**Repository rule:** 当前 worktree 有大量用户未提交改动；禁止 reset、worktree、广泛 stage、commit、push。所有修改留在当前 worktree，逐文件核对 diff。

---

### Task 1: Remove local `.gstack` artifacts and RSS surface

**Files:**
- Delete: `.gstack/browse-network.log`
- Delete: `.gstack/browse-audit.jsonl`
- Delete: `.gstack/claude-available.json`
- Delete: `follow-server/src/Follow.Api/Endpoints/RssEndpoints.cs`
- Delete: `follow-server/src/Follow.Core/Interfaces/IRssService.cs`
- Delete: `follow-server/src/Follow.Infrastructure/Services/RssService.cs`
- Delete: RSS entities and DTO files identified by `rg -n 'Rss|RSS'`
- Modify: `follow-server/src/Follow.Api/Program.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Data/FollowDbContext.cs`
- Modify: `follow-server/src/Follow.Core/Entities/User.cs`
- Modify: current README/reference/deployment/technical docs
- Test: `follow-server/tests/Follow.Api.Tests/RssRemovalContractTests.cs`

**Steps:**
1. Add a source-contract test asserting no endpoint registration, DI registration, current entity/DTO/service, or documentation advertises RSS.
2. Run the focused test and confirm it fails on current RSS registrations.
3. Delete only the three ignored `.gstack` files; no Git branch named `.gstack` exists.
4. Remove RSS runtime code and current documentation. Historical EF migrations remain immutable; the new migration drops their tables.
5. Run the focused test and `rg -n 'Rss|RSS|rss'` with historical migration exclusions.

### Task 2: Add hashed multi-device sessions and token transport contract

**Files:**
- Create: `follow-server/src/Follow.Core/Entities/UserSession.cs`
- Create: `follow-server/src/Follow.Shared/DTOs/SessionDtos.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/RefreshTokenProtector.cs`
- Modify: `follow-server/src/Follow.Core/Entities/User.cs`
- Modify: `follow-server/src/Follow.Core/Interfaces/IAuthService.cs`
- Modify: `follow-server/src/Follow.Core/Interfaces/IJwtService.cs`
- Modify: `follow-server/src/Follow.Shared/DTOs/AuthDtos.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/AuthService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/JwtService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Data/FollowDbContext.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/AuthEndpoints.cs`
- Test: `follow-server/tests/Follow.Api.Tests/AuthSessionServiceTests.cs`

**Contract:**
```text
UserSession(Id, UserId, RefreshTokenHash, PreviousRefreshTokenHash,
            CreatedAt, LastUsedAt, ExpiresAt, RotatedAt, RevokedAt,
            DeviceName, ClientType, UserAgent, Version)
AuthResponse(AccessToken?, RefreshToken?, SessionId, ExpiresAt, User)
TokenTransport = body | cookie
```

**Steps:**
1. Write failing tests for two independent device sessions, database hash-only storage, rotation, stale-token rejection, current/other/all-session revocation, and cross-user denial.
2. Run the focused tests and confirm failures are due to missing `UserSession` behavior.
3. Implement `sessionId.random32bytes` refresh tokens, SHA-256 storage, fixed-time comparison, optimistic-concurrency rotation, and `sid` access-token claim.
4. Make login/register create sessions instead of overwriting `User.RefreshToken`; remove legacy refresh fields.
5. Add `GET /api/auth/sessions`, `DELETE /api/auth/sessions/{id}`, `POST /api/auth/logout`, and `POST /api/auth/logout-all`.
6. Validate active `sid` on authenticated requests so revoked sessions stop immediately.
7. Run focused and full server tests.

### Task 3: Secure Web cookies, Flutter body tokens, and proper HTTP errors

**Files:**
- Create: `follow-server/src/Follow.Api/Auth/AuthCookieManager.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/AuthEndpoints.cs`
- Modify: `follow-server/src/Follow.Api/Middleware/GlobalExceptionHandler.cs`
- Modify: `follow-server/src/Follow.Api/Program.cs`
- Test: `follow-server/tests/Follow.Api.Tests/AuthEndpointContractTests.cs`

**Steps:**
1. Add failing endpoint tests for the `ApiResponse<AuthResponse>` envelope, cookie transport hiding tokens from JSON, body transport returning both tokens, cookie rotation/deletion, and 400/401/409 status codes.
2. Configure JWT bearer to read the HttpOnly access cookie only when no Authorization header exists.
3. For Web set `follow_access` at `/api` and `follow_refresh` at `/api/auth`, both HttpOnly, SameSite Strict and Secure when the forwarded request is HTTPS.
4. For Flutter return tokens in the existing response envelope and never set client-side browser storage.
5. Map validation/auth/conflict failures to correct HTTP status codes while keeping `ApiResponse` error bodies.
6. Run focused and full endpoint tests.

### Task 4: Add trusted-proxy-aware rate limiting

**Files:**
- Modify: `follow-server/src/Follow.Api/Program.cs`
- Modify: `follow-server/src/Follow.Api/appsettings.json`
- Modify: root and server Compose environment
- Test: `follow-server/tests/Follow.Api.Tests/RateLimitContractTests.cs`

**Steps:**
1. Add failing tests for auth 429 responses, `Retry-After`, per-user/IP partitioning, upload policy, and stream concurrency.
2. Configure forwarded headers before authentication/rate limiting; API is internal/loopback only, so forwarded headers are accepted only in that deployment boundary.
3. Add configurable named policies: register, login, refresh, API, upload and stream concurrency.
4. Return the standard API error envelope for rejections.
5. Run focused tests.

### Task 5: Replace buffered objects with HTTP Range streaming

**Files:**
- Modify: `follow-server/src/Follow.Core/Interfaces/IStorageService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/MinioStorageService.cs`
- Modify: `follow-server/src/Follow.Core/Interfaces/ITrackService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/TrackService.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/TrackEndpoints.cs`
- Create: `follow-server/src/Follow.Api/Media/RangeRequestParser.cs`
- Test: `follow-server/tests/Follow.Api.Tests/RangeRequestParserTests.cs`
- Test: `follow-server/tests/Follow.Api.Tests/TrackStreamingTests.cs`

**Contract:**
```text
GetObjectMetadataAsync(key) -> length/contentType/etag
CopyRangeToAsync(key, offset, length, destination, cancellationToken)
```

**Steps:**
1. Write failing tests for full response, `0-99`, open-ended, suffix, final byte, multi-range and unsatisfiable ranges.
2. Implement strict single-range parsing; return 200/206/416 with exact headers.
3. Use MinIO `StatObject` and `WithOffsetAndLength`; copy callback stream directly to `HttpResponse.Body` with `RequestAborted`.
4. Add HEAD behavior and remove MemoryStream-based track/cover/lyrics reads.
5. Restrict anonymous cover proxy to `covers/`, `artists/` and `albums/` prefixes plus supported image extensions.
6. Run range, API and full server tests.

### Task 6: Add transaction-safe object deletion outbox

**Files:**
- Create: `follow-server/src/Follow.Core/Entities/StorageDeletionJob.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/StorageDeletionQueue.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/StorageDeletionWorker.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Data/FollowDbContext.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/TrackService.cs`
- Modify: artist/album cover replacement services
- Test: `follow-server/tests/Follow.Api.Tests/TrackStorageConsistencyTests.cs`
- Test: `follow-server/tests/Follow.Api.Tests/StorageDeletionWorkerTests.cs`

**Steps:**
1. Add failing tests for upload compensation, safe replacement, deleting audio+cover+lyrics, retry and MinIO NotFound idempotency.
2. Add the deletion outbox and worker; restrict jobs to valid generated prefixes.
3. Upload new objects first; on DB failure delete the new object or enqueue compensation.
4. Replace references and enqueue old-object deletion in one DB transaction; never delete the live object first.
5. Delete track rows and enqueue all referenced objects in one DB transaction.
6. Run focused and full service tests.

### Task 7: Add playlist ownership and stable pagination contracts

**Files:**
- Modify: `follow-server/src/Follow.Shared/DTOs/PlaylistDtos.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/PlaylistService.cs`
- Create: `follow-server/src/Follow.Shared/DTOs/PaginationDtos.cs`
- Modify: track/admin/tag/history endpoints and services
- Test: `follow-server/tests/Follow.Api.Tests/PlaylistOwnershipTests.cs`
- Test: `follow-server/tests/Follow.Api.Tests/PaginationContractTests.cs`

**Steps:**
1. Add failing tests showing other users' public playlists are readable but not writable; owner metadata exposes no email/role; reorder must be a complete unique permutation.
2. Add `ownerId`, `ownerName`, `isOwnedByCurrentUser`, `canEdit` without accepting ownership from request payloads.
3. Validate `page >= 1`, `1 <= pageSize <= 100`, `1 <= history limit <= 100`; invalid values return 400.
4. Keep existing response field names for compatibility, add stable secondary `ThenBy(Id)`, `AsNoTracking`, and correct zero-page math.
5. Run focused and full tests.

### Task 8: Generate one EF migration for the unreleased schema transition

**Files:**
- Create: timestamped migration under `follow-server/src/Follow.Infrastructure/Data/Migrations/`
- Modify: `FollowDbContextModelSnapshot.cs`

**Migration:** drop `RssEpisodes`, `RssSubscriptions`, `Users.RefreshToken`, `Users.RefreshTokenExpiryTime`; create `UserSessions` and `StorageDeletionJobs` with indexes/FKs/concurrency fields.

**Steps:**
1. Generate migration from the final model; do not hand-edit historical migrations.
2. Inspect `Up` and `Down`; `Down` may restore empty RSS tables only.
3. Apply to a disposable copy or the current non-production database without deleting volumes.
4. Confirm existing users/tracks remain and old sessions require one login.

### Task 9: Move admin to same-origin cookie authentication and streaming audio

**Files:**
- Modify: `follow-admin/src/api/index.ts`
- Modify: `follow-admin/src/stores/auth.ts`
- Modify: `follow-admin/src/router/index.ts`
- Modify: `follow-admin/src/views/auth/LoginView.vue`
- Modify: `follow-admin/src/views/music/TracksView.vue`
- Modify: `follow-admin/vite.config.ts`
- Modify: `follow-admin/.env.development`
- Test: `follow-admin/tests/authSession.test.ts`
- Test: `follow-admin/tests/sameOriginApi.test.ts`

**Steps:**
1. Add failing tests asserting no token/refresh token localStorage, relative `/api`, one deduplicated cookie refresh/retry, async route restore and server logout.
2. Send `tokenTransport: cookie`; keep no JS token state and let HttpOnly access cookie authenticate requests/media.
3. On 401 call cookie refresh once, replay pending requests, and hard-logout only after refresh failure.
4. Make logout await `/api/auth/logout` before clearing UI state.
5. Replace Axios Blob preview with a same-origin `<audio src="/api/tracks/{id}/stream">` URL so the browser performs Range requests.
6. Run tests and production build.

### Task 10: Move Flutter auth to secure storage and expose device sessions

**Files:**
- Modify: `follow/pubspec.yaml` and lockfile
- Create: `follow/lib/data/services/auth/secure_token_store.dart`
- Modify: `follow/lib/data/services/api/api_client.dart`
- Modify: `follow/lib/data/services/api/api_service.dart`
- Modify: `follow/lib/data/providers/auth_provider.dart`
- Modify: `follow/lib/data/models/user.dart`
- Modify: `follow/lib/features/auth/login_page.dart`
- Modify: `follow/lib/features/settings/settings_page.dart`
- Modify: iOS/macOS entitlements and Android backup configuration
- Modify: playlist models/views/dialogs and library pagination UI
- Test: Flutter auth, secure storage, ownership and pagination tests

**Steps:**
1. Add failing tests for nested refresh envelope parsing, secure token reads/writes, best-effort server logout, no plaintext password persistence, and concurrent refresh deduplication.
2. Add `flutter_secure_storage`; keep only remembered email in SharedPreferences.
3. Send `tokenTransport: body` and device name; parse `response.data.data`; rotate both secure tokens atomically.
4. Call logout before local clear; always clear tokens/player/account-scoped state in `finally`.
5. Add session list/revoke UI under settings.
6. Parse playlist ownership and hide writes for public read-only playlists.
7. Wire track list load-more and preserve page boundaries.
8. Run code generation, analyze, tests, Android Debug and macOS Debug builds.

### Task 11: Add same-origin HTTPS gateway and close storage ports

**Files:**
- Create: `Caddyfile`
- Modify: `docker-compose.yml`
- Modify: `follow-server/docker-compose.yml`
- Modify: `follow-admin/nginx.conf`
- Modify: `follow-admin/Dockerfile`
- Modify: `.env.example`
- Modify: `scripts/verify-docker-config.sh`
- Modify: deployment/readme documents

**Steps:**
1. Add failing config assertions: gateway is the only LAN-facing service, API is loopback/internal, MinIO has no published ports, admin has no browser-visible API build arg, and external traffic is HTTPS.
2. Add Caddy with persistent local CA data; proxy `/api/*` to API and all other paths to admin.
3. Remove API absolute build URL; use Vite development proxy only.
4. Remove MinIO `ports`; preserve volumes and internal health checks.
5. Document exporting/trusting the Caddy local root CA and passing the gateway HTTPS URL to Flutter Release builds.
6. Run Compose config verification and rebuild without deleting volumes.

### Task 12: Cross-surface verification

**Steps:**
1. Run `git diff --check` and review only task-owned paths.
2. Run full .NET tests/build and migration against PostgreSQL.
3. Run admin tests/build.
4. Run Flutter code generation, analyze, tests, Android Debug and macOS Debug builds.
5. Start the Compose stack; verify HTTPS admin, cookie login/refresh/logout, two device sessions, 401 after revocation, 429 limits, MinIO/API exposure boundaries, 206 ranges and object cleanup jobs.
6. Verify existing user/track counts and play one real track without loading the complete object into API memory.
7. Report any unverified iOS/Windows/signing/device boundaries explicitly.
