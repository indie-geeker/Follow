# Playback, Embedded Metadata, and Admin Media Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make mobile playback controls functional, ingest embedded timed lyrics and covers consistently, safely backfill missing media references, and serve cover images through the packaged Admin origin.

**Architecture:** Keep the existing mutually exclusive `PlayMode` state as the only playback-mode source of truth. Move embedded media extraction and storage into shared server services consumed by manual upload, library initialization, and a bounded Admin-only backfill; keep Flutter responsible for presentation and explicit lyric error states. Give `/api/` priority in Nginx and verify the complete Admin-origin route.

**Tech Stack:** Flutter 3.41/Dart/Riverpod/just_audio, .NET 10/EF Core/TagLibSharp, PostgreSQL, MinIO, Vue 3/TypeScript/Element Plus, Nginx, Docker Compose, xUnit, Flutter Test, Node Test Runner.

---

## Execution rules

- Work in the current repository because the relevant implementation is already present as uncommitted work. Do not reset, clean, stash, or overwrite unrelated changes.
- Before each task, run `git status --short` and inspect the exact target-file diff.
- Follow red-green TDD: each behavioral change starts with a failing regression test, then the smallest implementation, then focused and broader verification.
- Commit commands below mark intended atomic boundaries. Run them only if the user explicitly authorizes commits; otherwise leave the verified changes uncommitted and report the exact files.
- Do not push, deploy, restart production, or run a non-dry-run backfill without separate authorization.

### Task 1: Replace dead mobile mode buttons with the shared play-mode state

**Files:**
- Create: `follow/test/shared/widgets/player/player_main_controls_test.dart`
- Modify: `follow/lib/shared/widgets/player/player_main_controls.dart`
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/lib/data/providers/audio_provider.dart`

**Step 1: Write the failing widget test**

Add a fake `AudioPlayerService` whose mode-application method only records the
requested mode. Pump the mobile controls inside `ProviderScope` and assert:

```dart
expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

await tester.tap(find.byTooltip('播放模式：顺序播放'));
await tester.pump();
expect(container.read(playerModeProvider), PlayMode.shuffle);
expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
```

Continue the test through `PlayMode.single` and back to `PlayMode.sequence`. Assert previous, play/pause, and next still delegate exactly once and every interactive target is at least 48dp.

**Step 2: Run the test and verify red**

Run from `follow/`:

```bash
fvm flutter test test/shared/widgets/player/player_main_controls_test.dart
```

Expected: FAIL because `PlayerMainControls` still exposes separate static shuffle/repeat buttons and cannot observe `playerModeProvider`.

**Step 3: Implement the smallest shared-mode control**

Move the just_audio-specific switch currently inside `PlayerMode.setMode` into
an overridable `AudioPlayerService.applyPlayMode(PlayMode mode)` method.
`PlayerMode.setMode` keeps ownership of Riverpod state and shuffle-index
generation, but delegates native loop/shuffle calls through that method. This
preserves production behavior and gives the widget test a safe fake boundary.

Convert `PlayerMainControls` to a `ConsumerWidget`, remove `onShuffle` and `onRepeat`, watch `playerModeProvider`, and render one tooltip-labelled dynamic button:

```dart
final mode = ref.watch(playerModeProvider);
final modeIcon = switch (mode) {
  PlayMode.sequence => Icons.repeat_rounded,
  PlayMode.shuffle => Icons.shuffle_rounded,
  PlayMode.single => Icons.repeat_one_rounded,
};

PlayerControlButton(
  icon: modeIcon,
  size: 24,
  tooltip: playModeTooltip(mode),
  onPressed: () => ref.read(playerModeProvider.notifier).nextMode(),
)
```

Keep only one mode button. Remove both empty callbacks from `PlayerPage`; do not add a second shuffle/repeat state.

If `PlayerControlButton` lacks tooltip support, add a required semantic label or tooltip without changing its visual design.

**Step 4: Run focused tests and verify green**

```bash
fvm flutter test test/shared/widgets/player/player_main_controls_test.dart
fvm flutter test test/shared/widgets/mini_player_layout_test.dart
```

Expected: PASS; the mobile control test finds one dynamic mode button and no dead repeat/shuffle pair.

**Step 5: Inspect the diff**

```bash
git diff -- follow/lib/shared/widgets/player/player_main_controls.dart follow/lib/features/player/player_page.dart follow/lib/data/providers/audio_provider.dart follow/test/shared/widgets/player/player_main_controls_test.dart
```

Expected: only the control contract, provider wiring, semantics, and regression tests changed.

**Step 6: Commit boundary, only when authorized**

```bash
git add follow/lib/shared/widgets/player/player_main_controls.dart follow/lib/features/player/player_page.dart follow/lib/data/providers/audio_provider.dart follow/test/shared/widgets/player/player_main_controls_test.dart
git commit -m "fix: connect mobile playback mode control"
```

### Task 2: Add mobile app-volume and mute controls

**Files:**
- Create: `follow/lib/shared/widgets/player/player_volume_control.dart`
- Create: `follow/test/shared/widgets/player/player_volume_control_test.dart`
- Modify: `follow/lib/data/providers/audio_provider.dart`
- Modify: `follow/lib/features/player/player_page.dart`
- Regenerate: `follow/lib/data/providers/audio_provider.g.dart` only if provider annotations change

**Step 1: Write failing pure and widget tests**

Test mute restoration separately from the audio plugin:

```dart
expect(nextMuteVolume(current: 0.65, lastAudible: 1.0), (0.0, 0.65));
expect(nextMuteVolume(current: 0.0, lastAudible: 0.65), (0.65, 0.65));
```

Pump `PlayerVolumeControl` with `playerVolumeProvider` overridden to `AsyncData(0.65)` and a fake `AudioPlayerService`. Assert:

- the slider value is `0.65`;
- dragging delegates the selected value to `setVolume`;
- tapping mute sends `0.0`;
- tapping again restores `0.65`;
- the tooltip and icon change between mute and unmute;
- controls remain usable at 320dp width.

**Step 2: Verify red**

```bash
fvm flutter test test/shared/widgets/player/player_volume_control_test.dart
```

Expected: FAIL because the widget and mute-restoration helper do not exist.

**Step 3: Implement the minimal volume behavior**

Add a small state object or pure helper in `audio_provider.dart` that preserves the last value greater than zero. Keep `AudioPlayerService.setVolume` as the only call that changes just_audio volume.

Build a compact row:

```dart
Row(
  children: [
    IconButton(tooltip: muted ? '取消静音' : '静音', onPressed: onToggleMute),
    Expanded(child: Slider(value: volume, onChanged: onChanged)),
  ],
)
```

Place it between the progress bar and main transport controls in `PlayerPage`. Do not alter Android system-volume APIs; this is app-level gain consistent with desktop.

**Step 4: Verify green and run nearby tests**

```bash
fvm flutter test test/shared/widgets/player/player_volume_control_test.dart
fvm flutter test test/shared/widgets/player/player_main_controls_test.dart
fvm flutter analyze
```

Expected: all tests pass and analyze reports no new issues.

**Step 5: Commit boundary, only when authorized**

```bash
git add follow/lib/shared/widgets/player/player_volume_control.dart follow/test/shared/widgets/player/player_volume_control_test.dart follow/lib/data/providers/audio_provider.dart follow/lib/features/player/player_page.dart follow/lib/data/providers/audio_provider.g.dart
git commit -m "feat: add mobile volume and mute controls"
```

### Task 3: Preserve lyric failures instead of converting them to “no lyrics”

**Files:**
- Create: `follow/test/data/services/lyrics_service_test.dart`
- Modify: `follow/lib/data/services/lyrics_service.dart`
- Modify: `follow/lib/data/providers/lyrics_provider.dart`
- Modify: `follow/lib/features/player/player_page.dart`
- Modify: `follow/lib/features/player/lyrics_overlay.dart`

**Step 1: Write failing service tests**

Allow an injected `Dio` or adapter and cover these cases:

```dart
test('returns timed lines for a valid LRC response', () async { /* 200 */ });
test('propagates a 404 for a referenced lyric object', () async { /* 404 */ });
test('throws LyricsFormatException when no timed line exists', () async { /* 200 plain text */ });
```

Also keep parser tests for two- and three-digit fractional seconds and add multiple timestamps on one line only if the parser is intentionally extended during this task.

**Step 2: Verify red**

```bash
fvm flutter test test/data/services/lyrics_service_test.dart
```

Expected: the request-error tests fail because `fetchLyrics` catches everything and returns `[]`.

**Step 3: Implement typed failure behavior**

Change `LyricsService` to accept an optional test Dio, remove the catch-all, and throw a typed format error when a fetched document produces no timed lines:

```dart
final lyrics = parseLrc(content);
if (lyrics.isEmpty) {
  throw const LyricsFormatException('未找到带时间戳的歌词');
}
return lyrics;
```

Keep `currentTrackLyricsProvider` returning `[]` only when `lyricsUrl` is genuinely absent.

**Step 4: Add retry UI**

In both mobile and desktop lyric views, render a visible error message and button. The retry callback must invalidate the provider:

```dart
ref.invalidate(currentTrackLyricsProvider);
```

Do not label errors as “暂无歌词”.

**Step 5: Verify green**

```bash
fvm flutter test test/data/services/lyrics_service_test.dart
fvm flutter test
fvm flutter analyze
```

Expected: all Flutter tests pass; valid empty metadata and failed referenced resources are visibly distinct.

**Step 6: Commit boundary, only when authorized**

```bash
git add follow/lib/data/services/lyrics_service.dart follow/lib/data/providers/lyrics_provider.dart follow/lib/features/player/player_page.dart follow/lib/features/player/lyrics_overlay.dart follow/test/data/services/lyrics_service_test.dart
git commit -m "fix: distinguish missing and failed lyrics"
```

### Task 4: Extract supported embedded cover art and timed LRC through one metadata contract

**Files:**
- Modify: `follow-server/src/Follow.Core/Interfaces/IAudioMetadataExtractor.cs`
- Create: `follow-server/src/Follow.Core/Services/EmbeddedLyricsPolicy.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/TagLibAudioMetadataExtractor.cs`
- Create: `follow-server/tests/Follow.Core.Tests/EmbeddedLyricsPolicyTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/TagLibAudioMetadataExtractorTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/Fixtures/synthetic-tagged.mp3`

**Step 1: Add failing policy tests**

Cover:

- valid `[00:01.20]text` and `[00:01.200]text` documents;
- metadata-only and plain unsynchronized lyrics;
- empty text;
- an oversized document;
- at least one valid timed line among metadata lines.

The result should state whether lyrics are supported without copying or logging lyric content.

**Step 2: Verify policy tests fail**

```bash
cd follow-server
dotnet test tests/Follow.Core.Tests/Follow.Core.Tests.csproj --filter FullyQualifiedName~EmbeddedLyricsPolicyTests
```

Expected: FAIL because `EmbeddedLyricsPolicy` does not exist.

**Step 3: Implement the policy and extend `AudioMetadata`**

Add `string? TimedLyrics` after the existing optional cover fields. Keep optional arguments so existing fake metadata construction remains source-compatible where possible.

Implement a bounded policy that returns normalized non-empty LRC only when at least one supported timestamp exists. Do not print the lyric text in logs or test output.

**Step 4: Add a synthetic extractor fixture and failing extractor test**

Use a tiny synthetic silent MP3 containing:

- title/artist/album tags;
- a small JPEG or PNG APIC frame;
- a USLT field containing a few generated LRC lines.

Do not use a real song or copyrighted cover. Assert MIME type, non-empty cover bytes, timed-lyric presence, and core metadata.

**Step 5: Verify extractor test fails**

```bash
dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter FullyQualifiedName~TagLibAudioMetadataExtractorTests -m:1
```

Expected: FAIL because the extractor currently omits pictures and lyrics.

**Step 6: Implement TagLib extraction**

Populate `CoverData`, `CoverContentType`, and `TimedLyrics` from `tagFile.Tag.Pictures` and `tagFile.Tag.Lyrics`. Accept only supported image MIME types and pass lyrics through `EmbeddedLyricsPolicy`.

**Step 7: Verify green**

```bash
dotnet test tests/Follow.Core.Tests/Follow.Core.Tests.csproj --filter FullyQualifiedName~EmbeddedLyricsPolicyTests
dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter FullyQualifiedName~TagLibAudioMetadataExtractorTests -m:1
```

Expected: both suites pass using only the synthetic fixture.

**Step 8: Commit boundary, only when authorized**

```bash
git add follow-server/src/Follow.Core/Interfaces/IAudioMetadataExtractor.cs follow-server/src/Follow.Core/Services/EmbeddedLyricsPolicy.cs follow-server/src/Follow.Infrastructure/Services/TagLibAudioMetadataExtractor.cs follow-server/tests/Follow.Core.Tests/EmbeddedLyricsPolicyTests.cs follow-server/tests/Follow.Api.Tests/TagLibAudioMetadataExtractorTests.cs follow-server/tests/Follow.Api.Tests/Fixtures/synthetic-tagged.mp3
git commit -m "feat: extract embedded cover and timed lyrics"
```

### Task 5: Persist embedded media consistently in manual upload and library initialization

**Files:**
- Create: `follow-server/src/Follow.Infrastructure/Services/EmbeddedTrackAssetWriter.cs`
- Create: `follow-server/tests/Follow.Api.Tests/EmbeddedTrackAssetWriterTests.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/TrackService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/MusicImportProcessor.cs`
- Modify: `follow-server/src/Follow.Api/Program.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportProcessorTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/TrackStorageConsistencyTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/ServiceFactory.cs`

**Step 1: Write failing asset-writer tests**

Use a recording `IStorageService` and verify:

- JPEG cover and UTF-8 LRC create managed `covers/{trackId}/...` and `lyrics/{trackId}/...` keys;
- unsupported cover MIME types are rejected before writing;
- cover-only and lyrics-only requests write only the requested object;
- failure on the second write deletes the first newly created object;
- returned references contain only successfully written objects.

**Step 2: Verify red**

```bash
dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter FullyQualifiedName~EmbeddedTrackAssetWriterTests -m:1
```

Expected: FAIL because the writer does not exist.

**Step 3: Implement the writer**

Use `IStorageService.UploadFileAsync` with sanitized fixed filenames such as `cover.jpg` and `lyrics.lrc`. Track every newly returned key. On failure, call `DeleteFileAsync` for only those new keys before rethrowing.

Expose a result similar to:

```csharp
public sealed record EmbeddedTrackAssetResult(
    string? CoverUrl,
    string? LyricsUrl,
    IReadOnlyList<string> NewObjectPaths);
```

**Step 4: Add failing manual-upload and import-processor tests**

Manual upload tests must prove the service uses `IAudioMetadataExtractor` rather than a second direct TagLib implementation. Import tests must prove a new track commits `CoverUrl` and `LyricsUrl` along with the audio object.

Add failure tests for:

- embedded-asset write failure cleans all new assets and does not leave references;
- database save failure compensates embedded assets;
- existing audio-object cleanup behavior remains intact;
- an exact duplicate does not write duplicate embedded assets.

**Step 5: Verify integration tests fail**

```bash
dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter "FullyQualifiedName~MusicImportProcessorTests|FullyQualifiedName~TrackStorageConsistencyTests" -m:1
```

Expected: new assertions fail because current import persistence ignores embedded assets and manual upload owns separate extraction code.

**Step 6: Refactor manual upload to the shared extractor**

Inject `IAudioMetadataExtractor` and `EmbeddedTrackAssetWriter` into `TrackService`. Replace its inline TagLib parsing with one extractor call against the seekable temporary stream. Preserve title, artist, album, duration, bitrate, and format behavior.

After the track ID exists, write embedded assets, assign their object keys, and save. Compensate new assets if the reference save fails. Preserve the existing uploaded-audio compensation and storage-deletion-outbox rules.

**Step 7: Integrate the writer into `MusicImportProcessor`**

After audio validation and before terminal completion, write embedded assets using the new track ID. Assign returned URLs before the database transaction commits. Extend failure cleanup to include all newly created paths without deleting an object owned by another lease.

Register the writer in `Program.cs` and update test factories explicitly.

**Step 8: Verify green and run server suites**

```bash
dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter "FullyQualifiedName~EmbeddedTrackAssetWriterTests|FullyQualifiedName~MusicImportProcessorTests|FullyQualifiedName~TrackStorageConsistencyTests" -m:1
dotnet test Follow.slnx -m:1
```

Expected: focused tests and the full server solution pass with zero failed tests.

**Step 9: Commit boundary, only when authorized**

```bash
git add follow-server/src/Follow.Infrastructure/Services/EmbeddedTrackAssetWriter.cs follow-server/src/Follow.Infrastructure/Services/TrackService.cs follow-server/src/Follow.Infrastructure/Services/MusicImportProcessor.cs follow-server/src/Follow.Api/Program.cs follow-server/tests/Follow.Api.Tests/EmbeddedTrackAssetWriterTests.cs follow-server/tests/Follow.Api.Tests/MusicImportProcessorTests.cs follow-server/tests/Follow.Api.Tests/TrackStorageConsistencyTests.cs follow-server/tests/Follow.Api.Tests/ServiceFactory.cs
git commit -m "feat: persist embedded track media"
```

### Task 6: Add a bounded, missing-only metadata backfill

**Files:**
- Create: `follow-server/src/Follow.Shared/DTOs/TrackMetadataBackfillDtos.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/TrackMetadataBackfillService.cs`
- Create: `follow-server/tests/Follow.Api.Tests/TrackMetadataBackfillServiceTests.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/AdminEndpoints.cs`
- Modify: `follow-server/src/Follow.Api/Program.cs`
- Create: `follow-server/tests/Follow.Api.Tests/TrackMetadataBackfillEndpointContractTests.cs`
- Modify: `follow-server/README.md`

**Step 1: Write failing service tests**

Cover:

- stable ID ordering with `afterId` and bounded `limit`;
- dry-run reports available missing assets without storage or database writes;
- execution fills null `CoverUrl` and `LyricsUrl` only;
- an existing administrator cover or lyric reference is never overwritten;
- a concurrent reference update wins and the now-unused new object is compensated;
- missing audio, unsupported lyrics, and extraction failures are isolated per track;
- repeating the same request is idempotent;
- the temporary file is deleted after success and failure.

**Step 2: Verify red**

```bash
dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter FullyQualifiedName~TrackMetadataBackfillServiceTests -m:1
```

Expected: FAIL because the service and DTOs do not exist.

**Step 3: Implement the bounded service**

Validate `1 <= limit <= 100`. Query only rows with at least one null media reference, ordered by ID. For each selected track:

```csharp
var objectMetadata = await storage.GetObjectMetadataAsync(track.FilePath, token);
await using var temp = CreateIsolatedTemporaryFile();
await storage.CopyRangeToAsync(track.FilePath, 0, objectMetadata.Length, temp, token);
temp.Position = 0;
var metadata = await extractor.ExtractAsync(temp, fileName, token);
```

In dry-run mode, report discoverable assets without writing. In execution mode, ask the writer for only missing assets, reload the row before assignment, save one track at a time, and compensate unused or failed new objects.

Return counts and per-track entries without returning lyric text or cover bytes.

**Step 4: Add failing endpoint contract tests**

Specify one Admin-only endpoint:

```text
POST /api/admin/tracks/metadata-backfill
{"dryRun":true,"afterId":null,"limit":50}
```

Test authentication/authorization, input bounds, DTO shape, and service delegation. Do not add an automatic startup invocation.

**Step 5: Verify endpoint tests fail**

```bash
dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter FullyQualifiedName~TrackMetadataBackfillEndpointContractTests -m:1
```

Expected: FAIL because the endpoint is not mapped.

**Step 6: Map the endpoint and document operations**

Register `TrackMetadataBackfillService`, map the Admin-only endpoint, and document:

1. dry-run first;
2. review candidate/supported/failed counts;
3. obtain explicit authorization;
4. execute one bounded page;
5. repeat using `nextAfterId`;
6. verify database references and media routes.

**Step 7: Verify green and full server suite**

```bash
dotnet test tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter "FullyQualifiedName~TrackMetadataBackfillServiceTests|FullyQualifiedName~TrackMetadataBackfillEndpointContractTests" -m:1
dotnet test Follow.slnx -m:1
```

Expected: all backfill tests and the full solution pass.

**Step 8: Commit boundary, only when authorized**

```bash
git add follow-server/src/Follow.Shared/DTOs/TrackMetadataBackfillDtos.cs follow-server/src/Follow.Infrastructure/Services/TrackMetadataBackfillService.cs follow-server/src/Follow.Api/Endpoints/AdminEndpoints.cs follow-server/src/Follow.Api/Program.cs follow-server/tests/Follow.Api.Tests/TrackMetadataBackfillServiceTests.cs follow-server/tests/Follow.Api.Tests/TrackMetadataBackfillEndpointContractTests.cs follow-server/README.md
git commit -m "feat: add safe embedded metadata backfill"
```

### Task 7: Give Admin API media routes precedence over static assets

**Files:**
- Create: `follow-admin/tests/nginxMediaProxy.test.ts`
- Modify: `follow-admin/nginx.conf`
- Modify: `scripts/verify-docker-config.sh`

**Step 1: Write the failing Nginx contract test**

Read `nginx.conf` and assert that the API location uses the `^~` prefix modifier and appears as a single API proxy definition:

```ts
assert.match(nginx, /location\s+\^~\s+\/api\/\s*\{/)
assert.equal((nginx.match(/proxy_pass\s+http:\/\/api:5000/g) ?? []).length, 2)
```

Also assert the extension-caching regex remains present for actual frontend assets.

**Step 2: Verify red**

Run from `follow-admin/`:

```bash
pnpm exec node --test tests/nginxMediaProxy.test.ts
```

Expected: FAIL because the current location is `location /api/`.

**Step 3: Implement the minimal Nginx fix**

Change only:

```nginx
location ^~ /api/ {
    proxy_pass http://api:5000;
    ...
}
```

Update `scripts/verify-docker-config.sh` to require the same priority marker. Do not weaken the guarded cover URL helper or expose MinIO.

**Step 4: Verify green and build Admin**

```bash
pnpm test
pnpm build
cd ..
./scripts/verify-docker-config.sh
```

Expected: all Node tests pass, Vue/TypeScript production build succeeds, and Docker config verification succeeds.

**Step 5: Commit boundary, only when authorized**

```bash
git add follow-admin/nginx.conf follow-admin/tests/nginxMediaProxy.test.ts scripts/verify-docker-config.sh
git commit -m "fix: proxy Admin media requests before static assets"
```

### Task 8: Run fresh cross-layer verification without executing the backfill

**Files:**
- Modify only if evidence exposes a defect in an earlier task.
- Record results in the implementation handoff; do not write credentials or lyric content into documentation.

**Step 1: Run all automated checks**

```bash
cd follow
fvm flutter test
fvm flutter analyze
cd ../follow-admin
pnpm test
pnpm build
cd ../follow-server
dotnet test Follow.slnx -m:1
cd ..
./scripts/verify-docker-config.sh
```

Expected: every command exits zero. Report exact test counts separately for Flutter, Admin, Core, and API tests.

**Step 2: Verify the Android UI locally**

Run the current Flutter app on the Android emulator. Confirm:

- one mode button cycles sequence, shuffle, single, and back to sequence;
- previous/play/next still work;
- the volume slider changes app audio gain;
- mute restores the prior non-zero value;
- missing lyrics display “暂无歌词”;
- a forced lyric request failure displays retry rather than “暂无歌词”.

This is emulator proof, not physical-device proof.

**Step 3: Rebuild only the local Admin container when authorized**

Record current Compose status first. Then rebuild/recreate only Admin, preserving PostgreSQL and MinIO volumes:

```bash
docker compose ps
docker compose build admin
docker compose up -d --no-deps admin
```

Do not use `down --volumes`, remove named volumes, or restart production.

**Step 4: Verify the known cover through both origins**

Use a cover object key returned by the authenticated local track API and request:

```bash
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' \
  'http://127.0.0.1:5050/api/tracks/cover/<encoded-object-key>'
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' \
  'http://127.0.0.1:3000/api/tracks/cover/<encoded-object-key>'
```

Expected: both return `200 image/<supported-type>`.

**Step 5: Run backfill dry-run only**

Using an authenticated local Admin session, submit:

```json
{"dryRun":true,"afterId":null,"limit":50}
```

Expected: the response reports candidates and discoverable embedded assets without changing PostgreSQL or MinIO. Verify before/after row references and object counts are unchanged.

Do not execute `dryRun:false` in this task.

**Step 6: Inspect final scope**

```bash
git status --short
git diff --check
git diff --stat
```

Expected: only the named implementation, tests, and documentation files changed; unrelated pre-existing dirty files remain untouched.

### Task 9: Separately authorize and execute historical backfill

**Prerequisite:** All previous automated and local runtime checks pass, dry-run results are reviewed, and the user explicitly authorizes data changes.

**Step 1: Capture a read-only baseline**

Record candidate track IDs, current `CoverUrl`/`LyricsUrl` nullness, and managed object counts. Do not include credentials or lyric text.

**Step 2: Execute one bounded page**

Call the same Admin endpoint with `dryRun:false` and the reviewed `afterId`/`limit`.

Expected: only null references are filled; manual references are unchanged; per-track failures do not roll back successful unrelated tracks.

**Step 3: Verify affected business routes**

For each updated track, verify:

- authenticated `GET /api/tracks/{id}` exposes the new references;
- `GET /api/tracks/{id}/lyrics` returns a timed LRC document without logging its content;
- direct and Admin-origin cover routes return the expected image type;
- Android displays and synchronizes lyrics;
- a second execution reports the rows as skipped/idempotent.

**Step 4: Report status boundaries**

Report separately:

- implemented;
- automated tests passed;
- Android emulator verified;
- local Docker Admin verified;
- backfill dry-run reviewed;
- backfill executed;
- physical device verified;
- deployed;
- production data verified.

Do not collapse local proof into deployment or production proof.

## Plan completion criteria

- The Android player page has no empty playback callbacks.
- Mobile and desktop use the same `PlayMode` source of truth.
- Mobile app-volume and mute behavior is tested.
- Manual upload and library initialization share embedded metadata extraction.
- Supported embedded covers and timed lyrics become managed objects with consistent database references.
- Existing manual media references are never overwritten by backfill.
- Flutter distinguishes absent lyrics from failed lyrics and exposes retry.
- The same cover returns `200` through the direct API and packaged Admin origins.
- Every automated suite passes freshly.
- No push, deployment, production change, or real backfill occurs without separate authorization.
