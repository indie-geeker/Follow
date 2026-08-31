# Manual Music Deduplication Review Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Route directory initialization, later directory imports, and browser uploads through one acoustic-analysis and manual-review workflow so no Track is created, skipped, or replaced until an administrator explicitly confirms the decision.

**Architecture:** Retain the existing `MusicImportBatch` worker and restart-safe job infrastructure, but add source kinds, analysis/group/review/apply phases, durable review groups, browser staging, acoustic fingerprints, quality facts, and audio-revision audit records. `fpcalc` produces versioned raw Chromaprint data; project-owned comparison code conservatively scores compatible fingerprints. Analysis never writes formal Track media. A separate apply worker revalidates confirmed decisions and either creates a Track or atomically replaces an existing Track's audio while preserving its identity.

**Tech Stack:** .NET 10, ASP.NET Core minimal APIs, EF Core/Npgsql/PostgreSQL, MinIO, TagLib#, Chromaprint `fpcalc`, FFmpeg-generated test fixtures, Vue 3, TypeScript, Element Plus, Vite, Node test runner, Docker Compose.

---

## Execution constraints

- Work in the current checkout and preserve every unrelated user change. Do not reset, clean, stage, commit, push, deploy, or touch production without separate authorization.
- Because the checkout is already dirty, every task ends with a scoped `git diff -- <listed paths>` checkpoint instead of the commit step normally used by `superpowers:writing-plans`.
- Use `superpowers:test-driven-development` for every behavior change: add the smallest failing test, prove the intended failure, implement the minimum behavior, and rerun the focused test.
- Use `superpowers:verification-before-completion` before claiming any task or the whole feature is complete.
- Use generated, non-copyrighted audio only. Never copy, rename, delete, or rewrite mounted source music.
- Apply schema migrations only to disposable local PostgreSQL during this plan. Production migration and deployment are outside scope.
- Never add an automatic decision path. Exact SHA matches and strong fingerprints may form groups and recommendations, but they may not select, reject, create, replace, or delete media.
- Existing Tracks are test data and are not backfilled. Their nullable fingerprint/quality fields are populated only when a future confirmed replacement occurs.
- All ingestion and preview endpoints remain administrator-only. APIs persist safe relative paths and object keys; they never expose host absolute paths.

## Approved behavior contract

The following invariants are acceptance criteria, not implementation suggestions:

1. Directory ingestion completes analysis of all eligible files before grouping or review.
2. Browser upload stages and analyzes the file, but returns `202 Accepted` with a review task rather than a new Track.
3. Every review group requires an explicit decision. A recommendation is presentation data only.
4. Same-recording transcodes may group; live, remaster, remix, cover, accompaniment, materially clipped, and uncertain variants remain separate unless the administrator says otherwise.
5. Replacing audio preserves the existing Track ID and its playlists, favorites, tags, and play history.
6. Mounted source media is read-only. Rejected browser staging objects are removed through the durable deletion workflow.
7. Restart preserves completed analysis, groups, decisions, and committed apply results.
8. If acoustic fingerprint capability is unavailable or incompatible, new ingestion is disabled; there is no SHA-only fallback.

## Target state and data model

Keep the existing internal `MusicImport*` names to limit migration and worker risk. The admin UI may label the feature “音乐入库/重复复核”.

### Enumerations

- `MusicImportSourceKind`: `MountedDirectory`, `BrowserStaging`.
- Extend batch status with `Analyzing`, `Grouping`, `AwaitingReview`, `ReadyToApply`, `Applying`, and retain terminal/pause/cancel states where their meaning remains valid.
- Extend item stage with `SourceValidation`, `Hashing`, `Metadata`, `Fingerprinting`, `Analyzed`, `Grouped`, `AwaitingReview`, `Applying`, `Verified`.
- `MusicImportReviewStatus`: `Open`, `Confirmed`, `Locked`, `Applied`, `Deferred`, `Conflict`, `Failed`.
- `MusicImportDecisionKind`: `CreateTrack`, `ReplaceExistingTrack`, `KeepExistingTrack`, `TreatAsSeparateRecording`, `RejectDuplicate`, `Defer`.
- `MusicImportMatchKind`: `None`, `ExactSha256`, `AcousticFingerprint`, `UserSeparated`.

### New durable records

- `MusicImportReviewGroup`: batch, status, optimistic `Version`, optional existing Track, recommended candidate, recommendation explanation, match kind, compatible fingerprint version, timestamps, confirmed administrator, and apply error.
- Extend `MusicImportItem`: source kind/reference, staging object key, source snapshot, metadata/quality facts, SHA-256, raw fingerprint payload/version/algorithm/duration, review group, match score/explanation, decision, selected existing Track, and apply result.
- Extend `Track`: nullable fingerprint payload/version/algorithm plus codec/container/lossless/sample rate/bit depth/channels/bitrate/exact duration and the selected content SHA-256.
- `TrackAudioRevision`: Track ID, prior and replacement object keys and media facts, hashes/fingerprints, acting administrator, review group, timestamps, and storage-cleanup job reference/status.

### API surface

- Existing directory task routes remain under `/api/admin/music-imports`.
- `POST /api/admin/music-imports/uploads`: stage one browser file and return `202 Accepted` with batch/item IDs.
- `GET /api/admin/music-imports/{batchId}/review-groups`: paged group summaries.
- `GET /api/admin/music-imports/review-groups/{groupId}`: full candidates and current version.
- `GET|HEAD /api/admin/music-imports/items/{itemId}/preview`: authenticated range-capable source/staging preview.
- `PUT /api/admin/music-imports/review-groups/{groupId}/decision`: explicit decision payload plus expected version.
- `POST /api/admin/music-imports/{batchId}/apply`: lock all confirmed decisions only when no open/deferred groups remain.
- `POST /api/admin/music-imports/{batchId}/accept-recommendations`: optional explicit bulk request containing every group ID, expected version, and candidate choice; the server does not infer omitted choices.

## Task 1: Lock the state machine and manual-decision domain contract

**Files:**

- Modify: `follow-server/src/Follow.Core/Entities/MusicImportBatch.cs`
- Modify: `follow-server/src/Follow.Core/Entities/MusicImportItem.cs`
- Modify: `follow-server/src/Follow.Core/Entities/MusicImportStatus.cs`
- Create: `follow-server/src/Follow.Core/Entities/MusicImportReviewGroup.cs`
- Create: `follow-server/src/Follow.Core/Entities/MusicImportReviewEnums.cs`
- Modify: `follow-server/tests/Follow.Core.Tests/MusicImportStateMachineTests.cs`
- Create: `follow-server/tests/Follow.Core.Tests/MusicImportReviewStateMachineTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportModelContractTests.cs`

**Step 1: Write failing state-transition tests**

Cover these cases:

- analysis completion enters `Grouping`, not `Running` or `Completed`;
- grouping completion with review groups enters `AwaitingReview`;
- `AwaitingReview` cannot enter `Applying` while any group is open or deferred;
- all explicit confirmations permit `ReadyToApply` and then `Applying`;
- recommendation fields never satisfy confirmation predicates;
- a stale group version cannot mutate a decision;
- pause/resume/cancel remain legal from analysis, grouping, review, and apply safe boundaries.

**Step 2: Prove the tests fail for the missing states and guards**

Run:

```bash
dotnet test follow-server/tests/Follow.Core.Tests/Follow.Core.Tests.csproj --filter 'FullyQualifiedName~MusicImportStateMachineTests|FullyQualifiedName~MusicImportReviewStateMachineTests'
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter FullyQualifiedName~MusicImportModelContractTests
```

Expected: compilation or assertion failures naming the new statuses, review entity, version, and explicit-confirmation rules.

**Step 3: Add the smallest domain model and transition guards**

Implement enums and entity fields. Put transition predicates in the Core state machine; do not let API or UI string comparisons define legality. Preserve existing terminal-state semantics.

**Step 4: Run the focused tests to green**

Run the two commands from Step 2. Expected: all selected tests pass.

**Step 5: Check scope**

```bash
git diff -- follow-server/src/Follow.Core/Entities follow-server/tests/Follow.Core.Tests follow-server/tests/Follow.Api.Tests/MusicImportModelContractTests.cs
```

Confirm there is no Track creation behavior and no default decision.

## Task 2: Define quality facts and advisory recommendation rules

**Files:**

- Create: `follow-server/src/Follow.Core/Models/AudioQualityFacts.cs`
- Create: `follow-server/src/Follow.Core/Models/MusicImportRecommendation.cs`
- Create: `follow-server/src/Follow.Core/Services/MusicImportQualityRecommendation.cs`
- Modify: `follow-server/src/Follow.Core/Entities/MusicImportItem.cs`
- Create: `follow-server/tests/Follow.Core.Tests/MusicImportQualityRecommendationTests.cs`

**Step 1: Write failing deterministic recommendation tests**

Test lossless over lossy, meaningful bit-depth/sample-rate comparison within lossless files, bitrate comparison within lossy files, metadata-completeness tie break, stable relative-path final tie break, and honest handling of unknown values. Assert both candidate ID and localized explanation facts.

Also prove the result contains no `Selected`, `Approved`, or mutation flag.

**Step 2: Run the failing tests**

```bash
dotnet test follow-server/tests/Follow.Core.Tests/Follow.Core.Tests.csproj --filter FullyQualifiedName~MusicImportQualityRecommendationTests
```

Expected: missing types/service failures.

**Step 3: Implement the pure recommendation service**

Keep ranking deterministic and explain every deciding comparison. Treat implausibly high sample rate or bit depth as data to display, not proof of subjective quality. Do not compare lossy bitrate directly against uncompressed bitrate.

**Step 4: Rerun to green and inspect the diff**

```bash
dotnet test follow-server/tests/Follow.Core.Tests/Follow.Core.Tests.csproj --filter FullyQualifiedName~MusicImportQualityRecommendationTests
git diff -- follow-server/src/Follow.Core/Models follow-server/src/Follow.Core/Services/MusicImportQualityRecommendation.cs follow-server/src/Follow.Core/Entities/MusicImportItem.cs follow-server/tests/Follow.Core.Tests/MusicImportQualityRecommendationTests.cs
```

## Task 3: Build and calibrate the project-owned fingerprint comparator

**Files:**

- Create: `follow-server/src/Follow.Core/Models/AudioFingerprint.cs`
- Create: `follow-server/src/Follow.Core/Models/AudioFingerprintMatch.cs`
- Create: `follow-server/src/Follow.Core/Options/AudioFingerprintMatchOptions.cs`
- Create: `follow-server/src/Follow.Core/Services/AudioFingerprintSimilarity.cs`
- Create: `follow-server/tests/Follow.Core.Tests/AudioFingerprintSimilarityTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/Fixtures/GeneratedAudioFixture.cs`
- Create: `follow-server/tests/Follow.Api.Tests/AudioFingerprintCalibrationTests.cs`

**Step 1: Write failing pure comparison tests**

Use small hand-authored `uint` sequences to specify:

- identical raw fingerprints score `1.0`;
- bounded bit changes lower the score predictably;
- compatible algorithm/version is required;
- insufficient overlap, duration mismatch, or excessive alignment offset is `Uncertain`, not a match;
- comparison is symmetric;
- empty or malformed data fails closed.

Use normalized Hamming distance over overlapping 32-bit frames with bounded alignment. Return score, overlap, chosen offset, and rejection reason; do not return a bare Boolean.

**Step 2: Prove the pure tests fail, then implement the minimum comparator**

```bash
dotnet test follow-server/tests/Follow.Core.Tests/Follow.Core.Tests.csproj --filter FullyQualifiedName~AudioFingerprintSimilarityTests
```

Implement only the tested scoring and compatibility rules, then rerun the command to green.

**Step 3: Generate the calibration matrix**

`GeneratedAudioFixture` must invoke local FFmpeg with `ProcessStartInfo.ArgumentList`, in a temporary directory, to create deterministic WAV source material and encode:

- same PCM: WAV, FLAC, MP3, AAC/M4A, OGG;
- same audio with changed tags and normal gain change;
- different waveform with identical metadata;
- synthetic intro/outro, clipped, live-like room response, remix-tempo, and cover-like melody variants.

Never add binary audio fixtures to Git.

**Step 4: Add a calibration test that initially fails**

The positive pairs must all score above every negative/uncertain pair with a documented safety margin. The test prints the score matrix and fails if no separating threshold exists. It must not quietly widen the match class.

Run:

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter FullyQualifiedName~AudioFingerprintCalibrationTests --logger 'console;verbosity=detailed'
```

Expected before adapter work: failure because real raw fingerprints are unavailable.

**Step 5: Do not choose a threshold yet**

Task 4 supplies real fingerprints. After that adapter is green, rerun this task's calibration test and set `AudioFingerprintMatchOptions` only if the matrix has a stable separating margin. Record the chosen threshold, minimum overlap, duration tolerance, and alignment bound in the test name/data and `appsettings.json`.

**Decision gate:** If generated same-recording encodings overlap materially with live/remix/cover negatives, stop implementation and report the score matrix. Do not ship a speculative threshold and do not replace fingerprint review with metadata matching.

## Task 4: Add a bounded `fpcalc` extraction adapter and capability check

**Files:**

- Create: `follow-server/src/Follow.Core/Interfaces/IAudioFingerprintService.cs`
- Create: `follow-server/src/Follow.Core/Models/AudioFingerprintCapability.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/FpcalcAudioFingerprintService.cs`
- Create: `follow-server/src/Follow.Infrastructure/Options/AudioFingerprintOptions.cs`
- Modify: `follow-server/src/Follow.Api/Program.cs`
- Modify: `follow-server/src/Follow.Api/appsettings.json`
- Modify: `follow-server/src/Follow.Api/appsettings.Development.json`
- Create: `follow-server/tests/Follow.Api.Tests/FpcalcAudioFingerprintServiceTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportConfigurationTests.cs`

**Step 1: Write failing adapter tests**

Use a fake executable/process seam for timeout, non-zero exit, malformed/oversized JSON, stderr bounds, cancellation, and version mismatch. Add one opt-in local integration case using generated audio and the real executable.

The invocation contract is `fpcalc -raw -signed -json -algorithm 2 -length 120 <private-temp-file>`. Copy the bounded source stream to a random, owner-only, seekable temporary file so MP4/M4A files with trailing indexes remain readable; pass the controlled path through `ArgumentList`, and delete it in `finally`. Parse signed JSON integers and store them as stable 32-bit frames. Use the trusted metadata duration because `fpcalc` reports zero duration for stdin/non-file streams. Capture executable version and algorithm.

**Step 2: Prove failure**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~FpcalcAudioFingerprintServiceTests|FullyQualifiedName~MusicImportConfigurationTests'
```

Expected: missing service/options/capability failures.

**Step 3: Implement the adapter**

Requirements:

- `ProcessStartInfo.ArgumentList`, no shell;
- streamed stdin and bounded stdout/stderr;
- configurable hard timeout and maximum output bytes;
- child-process termination on cancellation/timeout;
- exact algorithm/version data in the result;
- capability self-test at startup/readiness;
- ingestion disabled when capability is unavailable/incompatible;
- logs contain item IDs and error codes, never host paths or media contents.

**Step 4: Rerun adapter tests and calibration gate**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~FpcalcAudioFingerprintServiceTests|FullyQualifiedName~MusicImportConfigurationTests|FullyQualifiedName~AudioFingerprintCalibrationTests' --logger 'console;verbosity=detailed'
```

Set comparator defaults only after the Task 3 calibration gate passes.

**Step 5: Inspect scope**

```bash
git diff -- follow-server/src/Follow.Core/Interfaces follow-server/src/Follow.Core/Models/AudioFingerprintCapability.cs follow-server/src/Follow.Infrastructure/Services/FpcalcAudioFingerprintService.cs follow-server/src/Follow.Infrastructure/Options/AudioFingerprintOptions.cs follow-server/src/Follow.Api follow-server/tests/Follow.Api.Tests
```

## Task 5: Extend metadata extraction and persist the new schema

**Files:**

- Modify: `follow-server/src/Follow.Core/Entities/Track.cs`
- Create: `follow-server/src/Follow.Core/Entities/TrackAudioRevision.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/TagLibAudioMetadataExtractor.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Data/FollowDbContext.cs`
- Create: `follow-server/src/Follow.Infrastructure/Data/Migrations/<timestamp>_AddMusicIngestionReview.cs`
- Create: `follow-server/src/Follow.Infrastructure/Data/Migrations/<timestamp>_AddMusicIngestionReview.Designer.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Data/Migrations/FollowDbContextModelSnapshot.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MetadataWriteContractTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportModelContractTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportMigrationTests.cs`

**Step 1: Add failing model/metadata tests**

Assert codec, container, lossless, sample rate, bit depth, channels, bitrate, exact duration, hash, fingerprint version/algorithm/payload, review group version, and revision audit mappings. Confirm existing Track rows remain valid with nullable new columns.

**Step 2: Run focused tests to prove failure**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MetadataWriteContractTests|FullyQualifiedName~MusicImportModelContractTests|FullyQualifiedName~MusicImportMigrationTests'
```

**Step 3: Implement extraction and EF configuration**

Extend the existing TagLib-backed extractor. Normalize container/codec identifiers for display without treating tags as duplicate proof. Add database indexes for batch/status, group/status/version, content SHA, fingerprint version, existing Track, and apply result.

Store raw fingerprints in a bounded PostgreSQL representation selected by the migration test (for example compressed `bytea` with explicit frame count), not unbounded JSON text.

**Step 4: Generate a new additive migration**

Do not rewrite either existing migration. Generate a new migration after `20260727061608_AddMusicLibraryInitialization`:

```bash
dotnet ef migrations add AddMusicIngestionReview --project follow-server/src/Follow.Infrastructure --startup-project follow-server/src/Follow.Api
```

Review generated SQL for nullable Track additions, foreign keys, indexes, optimistic concurrency token, and rollback order.

**Step 5: Test migration against disposable PostgreSQL**

The test must migrate from an empty database and from the prior migration, insert an old-style Track, migrate forward, and verify the row still loads. It must not use EF InMemory for this proof.

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportMigrationTests|FullyQualifiedName~MetadataWriteContractTests|FullyQualifiedName~MusicImportModelContractTests'
git diff -- follow-server/src/Follow.Core/Entities follow-server/src/Follow.Infrastructure/Data follow-server/src/Follow.Infrastructure/Services/TagLibAudioMetadataExtractor.cs follow-server/tests/Follow.Api.Tests
```

## Task 6: Unify mounted-directory and browser-staging source reads

**Files:**

- Create: `follow-server/src/Follow.Core/Interfaces/IMusicImportSourceReader.cs`
- Create: `follow-server/src/Follow.Core/Models/MusicImportSourceSnapshot.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportSourceReader.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/MusicImportScanner.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/MusicImportService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Storage/ImportObjectPath.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportSourceReaderTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportBrowserUploadTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportScannerTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/ImportObjectPathContractTests.cs`

**Step 1: Write failing source-reader and upload tests**

Test safe mounted relative-path reads, traversal/symlink rejection, read-only behavior, snapshot capture, snapshot-change detection, MinIO staging key isolation (`tracks/staging/{itemId}/...`), allowed extension/content-size enforcement, partial upload cleanup, cancellation, and `202 Accepted` without any Track row.

**Step 2: Prove failure**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportSourceReaderTests|FullyQualifiedName~MusicImportBrowserUploadTests|FullyQualifiedName~MusicImportScannerTests|FullyQualifiedName~ImportObjectPathContractTests'
```

**Step 3: Implement one stream abstraction**

Both source kinds expose a read stream plus an immutable snapshot descriptor. The mounted reader reuses the existing path policy. The staging reader uses MinIO and never turns an object key into a filesystem path.

Browser upload creates a one-item batch and staged item, but never calls `ITrackService.UploadAsync` and never writes `tracks/{trackId}/...`.

**Step 4: Rerun to green and inspect scope**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportSourceReaderTests|FullyQualifiedName~MusicImportBrowserUploadTests|FullyQualifiedName~MusicImportScannerTests|FullyQualifiedName~ImportObjectPathContractTests'
git diff -- follow-server/src/Follow.Core/Interfaces follow-server/src/Follow.Core/Models/MusicImportSourceSnapshot.cs follow-server/src/Follow.Infrastructure/Services/MusicImportSourceReader.cs follow-server/src/Follow.Infrastructure/Services/MusicImportScanner.cs follow-server/src/Follow.Infrastructure/Services/MusicImportService.cs follow-server/src/Follow.Infrastructure/Storage/ImportObjectPath.cs follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs follow-server/tests/Follow.Api.Tests
```

## Task 7: Split analysis from grouping and prohibit pre-review Track writes

**Files:**

- Modify: `follow-server/src/Follow.Infrastructure/Services/MusicImportProcessor.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportAnalysisProcessor.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportGroupingService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/MusicImportWorker.cs`
- Modify: `follow-server/src/Follow.Infrastructure/DependencyInjection.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportProcessorTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportWorkerTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportAnalysisProcessorTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportGroupingServiceTests.cs`

**Step 1: Write failing two-phase tests**

Prove:

- every eligible directory item reaches a durable analyzed state before grouping starts;
- each analysis persists source snapshot, SHA, metadata, quality, and fingerprint;
- analysis creates no Track and writes no formal object;
- exact SHA items form a review group but are not auto-rejected;
- calibrated fingerprint matches form a review group with score/explanation;
- metadata-only similarity never forms a definitive group;
- different/uncertain recordings remain independent review groups;
- existing compatible Track fingerprints can seed groups, while Tracks without fingerprints do not become acoustic matches;
- restart claims only unfinished safe units.

**Step 2: Run and observe failure**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportAnalysisProcessorTests|FullyQualifiedName~MusicImportGroupingServiceTests|FullyQualifiedName~MusicImportProcessorTests|FullyQualifiedName~MusicImportWorkerTests'
```

Expected: existing processor creates Track/object too early and lacks grouping phase.

**Step 3: Implement analysis as an idempotent per-item unit**

Read the source once where practical while hashing, metadata extraction, and fingerprint streaming remain bounded. Persist one completed stage at a time. A retry must not duplicate analysis records.

**Step 4: Implement durable grouping**

Compare exact SHA first, then compatible fingerprints using Task 3's calibrated options. Use bounded candidate queries and persist group membership incrementally; do not load an entire library's raw fingerprints into memory. Generate one standalone review group for each unmatched candidate so every item still receives an explicit decision.

**Step 5: Remove pre-review side effects from the old processor**

The existing `MusicImportProcessor` may become a small phase dispatcher or be retired after callers are migrated. Delete no user code blindly; prove all references moved with `rg`.

**Step 6: Rerun to green and inspect forbidden writes**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportAnalysisProcessorTests|FullyQualifiedName~MusicImportGroupingServiceTests|FullyQualifiedName~MusicImportProcessorTests|FullyQualifiedName~MusicImportWorkerTests'
rg -n 'Add\(.*Track|Tracks\.Add|PutObject|UploadAsync' follow-server/src/Follow.Infrastructure/Services/MusicImportAnalysisProcessor.cs follow-server/src/Follow.Infrastructure/Services/MusicImportGroupingService.cs
git diff -- follow-server/src/Follow.Infrastructure/Services follow-server/src/Follow.Infrastructure/DependencyInjection.cs follow-server/tests/Follow.Api.Tests
```

Expected `rg`: no Track creation or formal-object upload in analysis/grouping code.

## Task 8: Add authenticated, range-capable candidate preview

**Files:**

- Create: `follow-server/src/Follow.Core/Interfaces/IMusicImportPreviewService.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportPreviewService.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs`
- Reuse or modify: `follow-server/src/Follow.Api/Media/StorageObjectResult.cs`
- Create: `follow-server/src/Follow.Api/Media/SourceStreamResult.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportPreviewTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/RangeRequestParserTests.cs`

**Step 1: Write failing endpoint tests**

Cover admin authorization, GET/HEAD, full response, valid/suffix/open-ended ranges, invalid/multiple ranges, mounted-source snapshot revalidation, staging-object not found, MIME type, content length, cancellation, and absence of absolute paths in headers/body/log payloads.

**Step 2: Prove failure, implement, rerun**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportPreviewTests|FullyQualifiedName~RangeRequestParserTests'
```

Reuse the existing range parser and storage result behavior. Mounted reads must stay within the validated root and must not buffer the whole file.

Rerun the same command, then:

```bash
git diff -- follow-server/src/Follow.Core/Interfaces/IMusicImportPreviewService.cs follow-server/src/Follow.Infrastructure/Services/MusicImportPreviewService.cs follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs follow-server/src/Follow.Api/Media follow-server/tests/Follow.Api.Tests
```

## Task 9: Implement optimistic manual decisions and explicit batch locking

**Files:**

- Create: `follow-server/src/Follow.Shared/DTOs/MusicImportReviewDtos.cs`
- Create: `follow-server/src/Follow.Core/Interfaces/IMusicImportReviewService.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportReviewService.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportReviewServiceTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportEndpointContractTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportReviewConcurrencyTests.cs`

**Step 1: Write failing service and endpoint tests**

Test every approved decision kind and require explicit candidate IDs. Reject recommendation-only payloads, invalid cross-group candidates, replacements without an existing Track, unresolved groups, repeated apply requests, stale versions, non-admin callers, and bulk payloads that omit any advertised group.

Use real disposable PostgreSQL for two simultaneous updates with the same expected version; exactly one must succeed and the other must receive `409 Conflict` with the current representation.

**Step 2: Run failing tests**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportReviewServiceTests|FullyQualifiedName~MusicImportEndpointContractTests|FullyQualifiedName~MusicImportReviewConcurrencyTests'
```

**Step 3: Implement explicit decisions**

Persist the acting administrator and complete decision payload. `POST .../apply` changes confirmed groups to `Locked` in one transaction only after all groups are resolved. A locked or applied group is immutable except through a separately designed administrative recovery path; do not add one in this scope.

**Step 4: Rerun and inspect**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportReviewServiceTests|FullyQualifiedName~MusicImportEndpointContractTests|FullyQualifiedName~MusicImportReviewConcurrencyTests'
git diff -- follow-server/src/Follow.Shared/DTOs/MusicImportReviewDtos.cs follow-server/src/Follow.Core/Interfaces/IMusicImportReviewService.cs follow-server/src/Follow.Infrastructure/Services/MusicImportReviewService.cs follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs follow-server/tests/Follow.Api.Tests
```

## Task 10: Apply confirmed new-Track decisions safely

**Files:**

- Create: `follow-server/src/Follow.Core/Interfaces/IMusicImportApplyService.cs`
- Create: `follow-server/src/Follow.Infrastructure/Services/MusicImportApplyService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/MusicImportWorker.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Storage/ImportObjectPath.cs`
- Modify: `follow-server/src/Follow.Infrastructure/DependencyInjection.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportApplyServiceTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/TrackStorageConsistencyTests.cs`

**Step 1: Write failing create-decision tests**

Prove the service:

- refuses open, deferred, stale, or recommendation-only groups;
- revalidates source snapshot, SHA, fingerprint, and decision version;
- writes only the selected candidate to a deterministic revision-specific managed object key;
- verifies object length/hash/readability before DB commit;
- creates exactly one Track and links rejected duplicates only after explicit confirmation;
- removes or durably queues an orphan new object after DB failure;
- is idempotent after crash/restart and never creates two Tracks for one group;
- leaves mounted sources untouched and queues rejected staging objects for deletion.

**Step 2: Prove existing behavior fails**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportApplyServiceTests|FullyQualifiedName~TrackStorageConsistencyTests'
```

**Step 3: Implement the create path**

Use a new object key that cannot overwrite another revision. Place storage write/verification before the database transaction and compensate through the existing durable deletion mechanism if the transaction fails. Add a database uniqueness constraint or idempotency key for one apply result per group.

**Step 4: Rerun and inspect**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportApplyServiceTests|FullyQualifiedName~TrackStorageConsistencyTests'
git diff -- follow-server/src/Follow.Core/Interfaces/IMusicImportApplyService.cs follow-server/src/Follow.Infrastructure/Services/MusicImportApplyService.cs follow-server/src/Follow.Infrastructure/Services/MusicImportWorker.cs follow-server/src/Follow.Infrastructure/Storage/ImportObjectPath.cs follow-server/src/Follow.Infrastructure/DependencyInjection.cs follow-server/tests/Follow.Api.Tests
```

## Task 11: Apply replacement decisions while preserving Track identity

**Files:**

- Modify: `follow-server/src/Follow.Infrastructure/Services/MusicImportApplyService.cs`
- Modify: `follow-server/src/Follow.Core/Entities/TrackAudioRevision.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Data/FollowDbContext.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/StorageDeletionQueue.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/StorageDeletionWorker.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportReplacementTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/StorageDeletionWorkerTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/PlaylistOwnershipTests.cs`

**Step 1: Write failing replacement tests**

Build a Track referenced by playlists, favorites, tags, and play history. Confirm replacement:

- preserves the Track primary key and all relationships;
- writes/verifies a new revision object before changing the Track;
- updates media facts/hash/fingerprint and records old/new facts in `TrackAudioRevision` in one PostgreSQL transaction;
- queues old-object deletion only after commit;
- leaves the old Track/object authoritative on DB failure;
- keeps the working new Track when old-object cleanup fails and exposes retry state;
- cleans the losing new object after a concurrent replacement conflict;
- is restart-idempotent.

**Step 2: Run failing tests**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportReplacementTests|FullyQualifiedName~StorageDeletionWorkerTests|FullyQualifiedName~PlaylistOwnershipTests'
```

**Step 3: Implement the replacement transaction and post-commit cleanup**

Do not delete or overwrite the old object inside the Track transaction. Persist the revision audit and cleanup job together with the Track update, then let the existing deletion worker retry independently.

**Step 4: Rerun and inspect the Track-ID proof**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportReplacementTests|FullyQualifiedName~StorageDeletionWorkerTests|FullyQualifiedName~PlaylistOwnershipTests'
git diff -- follow-server/src/Follow.Infrastructure/Services/MusicImportApplyService.cs follow-server/src/Follow.Core/Entities/TrackAudioRevision.cs follow-server/src/Follow.Infrastructure/Data/FollowDbContext.cs follow-server/src/Follow.Infrastructure/Services/StorageDeletionQueue.cs follow-server/src/Follow.Infrastructure/Services/StorageDeletionWorker.cs follow-server/tests/Follow.Api.Tests
```

## Task 12: Retire the immediate ordinary-upload path

**Files:**

- Modify: `follow-server/src/Follow.Core/Interfaces/ITrackService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/TrackService.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/TrackEndpoints.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/UploadLimitContractTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/TrackUploadReviewRoutingTests.cs`

**Step 1: Write a failing regression test**

POST an ordinary admin upload and assert:

- response is `202` with ingestion batch/item IDs;
- a staging object and import item exist;
- no Track and no formal Track object exist;
- fingerprint-unavailable readiness returns a clear service-unavailable/business error rather than importing with SHA only.

Also assert no public/non-admin route can bypass review.

**Step 2: Prove current upload creates a Track**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~TrackUploadReviewRoutingTests|FullyQualifiedName~UploadLimitContractTests'
```

Expected: the new test observes the old immediate `201 Track` behavior.

**Step 3: Route the endpoint to the shared ingestion service**

Prefer updating the admin client to the new `/api/admin/music-imports/uploads` route. If `/api/tracks/upload` must remain temporarily for compatibility, make it an admin-only compatibility wrapper returning the same `202` ingestion DTO; it must not call the old Track-creation code. Remove the now-unused upload method only after `rg` proves no safe caller remains.

**Step 4: Rerun and search for bypasses**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~TrackUploadReviewRoutingTests|FullyQualifiedName~UploadLimitContractTests'
rg -n 'UploadAsync\(|MapPost\(".*/upload|Tracks\.Add' follow-server/src
git diff -- follow-server/src/Follow.Core/Interfaces/ITrackService.cs follow-server/src/Follow.Infrastructure/Services/TrackService.cs follow-server/src/Follow.Api/Endpoints follow-server/tests/Follow.Api.Tests
```

Every surviving upload call must be either staging or a confirmed apply operation.

## Task 13: Expose complete review DTOs and capability/progress states

**Files:**

- Modify: `follow-server/src/Follow.Shared/DTOs/MusicImportDtos.cs`
- Modify: `follow-server/src/Follow.Shared/DTOs/MusicImportReviewDtos.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/MusicImportService.cs`
- Modify: `follow-server/src/Follow.Infrastructure/Services/MusicImportReviewService.cs`
- Modify: `follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportServiceTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/MusicImportEndpointContractTests.cs`

**Step 1: Add failing contract tests**

Require source/fingerprint readiness, phase counts, candidate quality facts, safe source label, match type/score/explanation, recommendation and its explanation, explicit decision/status/version, existing Track facts, preview availability, apply/cleanup error codes, and pagination.

Assert DTOs never include absolute source paths, MinIO credentials, or a Boolean implying recommendation acceptance.

**Step 2: Run, implement projections, rerun**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportServiceTests|FullyQualifiedName~MusicImportEndpointContractTests'
```

Implement server-side projections with bounded queries; avoid N+1 fingerprint/Track lookups. Rerun the same command and inspect:

```bash
git diff -- follow-server/src/Follow.Shared/DTOs follow-server/src/Follow.Infrastructure/Services/MusicImportService.cs follow-server/src/Follow.Infrastructure/Services/MusicImportReviewService.cs follow-server/src/Follow.Api/Endpoints/MusicImportEndpoints.cs follow-server/tests/Follow.Api.Tests
```

## Task 14: Add the admin review client and pure decision model

**Files:**

- Modify: `follow-admin/src/types/musicImport.ts`
- Modify: `follow-admin/src/api/musicImportClient.ts`
- Modify: `follow-admin/src/api/musicImports.ts`
- Create: `follow-admin/src/utils/musicImportReview.ts`
- Modify: `follow-admin/tests/musicImportApi.test.ts`
- Create: `follow-admin/tests/musicImportReviewModel.test.ts`

**Step 1: Write failing TypeScript tests**

Test response parsing, enum handling, quality labels, match explanations, recommendation display, decision validation, exact expected-version payloads, bulk payload completeness, conflict normalization, and absence of a default candidate selection.

**Step 2: Run and prove failure**

```bash
pnpm --dir follow-admin test -- musicImportApi.test.ts musicImportReviewModel.test.ts
```

If the repository's test script does not forward filenames, run its underlying `node --test` command with the two exact paths.

**Step 3: Implement the typed client and pure helpers**

Initializing a review form must leave `decision` and `candidateId` unset even when `recommendedItemId` exists. Only a user action may populate them.

**Step 4: Rerun and inspect**

```bash
pnpm --dir follow-admin test -- musicImportApi.test.ts musicImportReviewModel.test.ts
git diff -- follow-admin/src/types/musicImport.ts follow-admin/src/api/musicImportClient.ts follow-admin/src/api/musicImports.ts follow-admin/src/utils/musicImportReview.ts follow-admin/tests/musicImportApi.test.ts follow-admin/tests/musicImportReviewModel.test.ts
```

## Task 15: Build the manual-review UI

**Files:**

- Create: `follow-admin/src/views/music/imports/MusicImportReviewView.vue`
- Create: `follow-admin/src/views/music/imports/MusicImportReviewGroupCard.vue`
- Modify: `follow-admin/src/views/music/imports/MusicImportDetailView.vue`
- Modify: `follow-admin/src/views/music/imports/MusicImportListView.vue`
- Modify: `follow-admin/src/router/index.ts`
- Modify: `follow-admin/src/styles/admin-components.css`
- Modify: `follow-admin/tests/musicImportUiContract.test.ts`
- Create: `follow-admin/tests/musicImportReviewUiContract.test.ts`

**Step 1: Add failing UI contract tests**

Require:

- route `/tracks/imports/:jobId/review`;
- grouped candidates with format, codec, lossless, sample rate, bit depth, channels, bitrate, size, duration, source, match score, and explanation;
- recommendation badge that is visually distinct from an actual selection;
- no pre-checked radio, implicit first item, or automatic decision initialization;
- preview controls using the authenticated preview URL;
- explicit create, replace, keep, separate, reject, defer actions;
- a second-confirmation dialog before bulk recommendation acceptance and before apply;
- disabled apply while any group is open/deferred;
- stale-version conflict refresh path;
- keyboard labels and accessible status/error text.

**Step 2: Prove failure**

```bash
pnpm --dir follow-admin test -- musicImportUiContract.test.ts musicImportReviewUiContract.test.ts
```

**Step 3: Implement the review view**

Use paged group loading and lazy candidate preview. Do not preload audio. Never convert `recommendedItemId` to the form's selected candidate. Clearly label “系统建议” and “管理员已选择” as different states.

**Step 4: Rerun tests and build**

```bash
pnpm --dir follow-admin test -- musicImportUiContract.test.ts musicImportReviewUiContract.test.ts
pnpm --dir follow-admin build
git diff -- follow-admin/src/views/music/imports follow-admin/src/router/index.ts follow-admin/src/styles/admin-components.css follow-admin/tests
```

## Task 16: Route the Tracks page upload into review

**Files:**

- Modify: `follow-admin/src/views/music/TracksView.vue`
- Modify: `follow-admin/src/api/upload.ts`
- Modify: `follow-admin/src/api/musicImports.ts`
- Modify: `follow-admin/tests/musicImportUiContract.test.ts`
- Modify: `follow-admin/tests/musicImportApi.test.ts`

**Step 1: Add a failing regression test**

Assert browser upload posts to the staging ingestion endpoint, treats `202` as success, shows “已提交分析，尚未入库”, and navigates to the task/detail or review page. Assert it never appends a Track to the table directly.

**Step 2: Prove current behavior fails, implement, rerun**

```bash
pnpm --dir follow-admin test -- musicImportUiContract.test.ts musicImportApi.test.ts
```

Update the upload action and user messaging. Keep the directory initialization entry point, but use the shared queue/progress vocabulary.

```bash
pnpm --dir follow-admin test -- musicImportUiContract.test.ts musicImportApi.test.ts
pnpm --dir follow-admin build
git diff -- follow-admin/src/views/music/TracksView.vue follow-admin/src/api/upload.ts follow-admin/src/api/musicImports.ts follow-admin/tests
```

## Task 17: Package and verify the fingerprint runtime reproducibly

**Files:**

- Modify: `follow-server/Dockerfile`
- Modify: `docker-compose.yml`
- Modify: `docker-compose.prod.yml`
- Modify: `.env.example`
- Modify: `scripts/verify-docker-config.sh`
- Modify: `follow-server/README.md`
- Modify: `README.md`
- Create: `follow-server/tests/Follow.Api.Tests/FingerprintRuntimeContractTests.cs`

**Step 1: Add failing runtime/config tests**

Assert the runtime image contains compatible `fpcalc` and FFmpeg commands, the configured algorithm/length/timeout/output limit are explicit, readiness fails closed, and Compose does not make mounted media writable.

**Step 2: Run current config checks and record failure**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter FullyQualifiedName~FingerprintRuntimeContractTests
bash scripts/verify-docker-config.sh
```

**Step 3: Add a pinned runtime**

Build or copy Chromaprint from a pinned official release/tag and verified checksum; do not use an unversioned curl-to-shell install. Record the expected `fpcalc` version in image metadata and readiness. Include the FFmpeg runtime needed for supported decoding, also from a reproducible package/image source.

At implementation time, verify the pinned official version and checksum before editing the Dockerfile. Do not silently bump it during unrelated work.

**Step 4: Verify image and Compose locally**

```bash
docker compose config >/dev/null
docker compose -f docker-compose.prod.yml config >/dev/null
bash scripts/verify-docker-config.sh
docker build --target final -t follow-server:fingerprint-review -f follow-server/Dockerfile .
docker run --rm follow-server:fingerprint-review fpcalc -version
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter FullyQualifiedName~FingerprintRuntimeContractTests
```

Expected: version matches the configured compatible version; read-only music mount remains read-only.

**Step 5: Inspect deployment-file scope without deploying**

```bash
git diff -- follow-server/Dockerfile docker-compose.yml docker-compose.prod.yml .env.example scripts/verify-docker-config.sh follow-server/README.md README.md follow-server/tests/Follow.Api.Tests/FingerprintRuntimeContractTests.cs
```

## Task 18: Prove restart safety, PostgreSQL concurrency, and MinIO cleanup end to end

**Files:**

- Create: `follow-server/tests/Follow.Api.Tests/Infrastructure/DisposableMusicImportStack.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportEndToEndTests.cs`
- Create: `follow-server/tests/Follow.Api.Tests/MusicImportRestartRecoveryTests.cs`
- Modify: `follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj`
- Create: `scripts/verify-music-import-review.sh`

**Step 1: Write failing isolated integration scenarios**

Use a temporary read-only directory, generated audio, disposable PostgreSQL, and disposable MinIO. Cover:

1. analyze all → group same-recording encodings → no Track;
2. restart after partial analysis → resume without duplicates;
3. manually choose non-recommended candidate → exact chosen file becomes Track;
4. mark fingerprint-near variants separate → two Tracks only after explicit decisions;
5. replace existing Track → same ID/relationships, new playable object, old cleanup queued;
6. crash after object write before DB commit → orphan cleanup and safe retry;
7. two browser uploads/decisions race → one version wins, loser cleans up;
8. reject/cancel browser staging → durable deletion completes;
9. authenticated final Track range stream returns playable bytes.

**Step 2: Prove the scenarios fail before the harness/remaining behavior exists**

```bash
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj --filter 'FullyQualifiedName~MusicImportEndToEndTests|FullyQualifiedName~MusicImportRestartRecoveryTests' --logger 'console;verbosity=detailed'
```

**Step 3: Implement the disposable harness and smallest missing integration seams**

The harness must use unique database/bucket names and delete only those explicit test resources. It must never read workspace music or connect to configured production hosts.

**Step 4: Run the isolated script twice**

```bash
bash scripts/verify-music-import-review.sh
bash scripts/verify-music-import-review.sh
```

The second run proves cleanup and idempotent setup. Save only text logs; do not save generated audio.

**Step 5: Inspect scope**

```bash
git diff -- follow-server/tests/Follow.Api.Tests/Infrastructure follow-server/tests/Follow.Api.Tests/MusicImportEndToEndTests.cs follow-server/tests/Follow.Api.Tests/MusicImportRestartRecoveryTests.cs follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj scripts/verify-music-import-review.sh
```

## Task 19: Perform admin browser QA without changing production

**Files:**

- Modify only if a reproduced defect requires a new failing test first.
- Record evidence under an ignored temporary directory, not source control.

**Step 1: Start only the isolated local stack**

Use disposable PostgreSQL/MinIO and generated audio. Confirm the configured URLs are loopback/test resources before starting.

**Step 2: Use `gstack-browse` for the complete interaction chain**

Verify at desktop widths used by the admin app:

- create directory task and observe analyze → group → review;
- upload one file and observe `202`/review redirection;
- recommendation is highlighted but nothing is selected;
- audio preview and range seeking work;
- choose a non-recommended candidate and confirm it is honored;
- exercise keep/replace/separate/reject/defer;
- stale two-tab decision shows conflict and refresh;
- bulk recommendation requires explicit second confirmation;
- apply remains disabled with unresolved groups;
- final Track streams through authenticated route;
- keyboard focus, labels, error text, narrow layout, and long filenames remain usable.

**Step 3: Fix only reproduced defects with TDD**

For each defect: add a failing focused test, capture the failure, implement the minimum fix, rerun the test, then repeat the browser action. Do not make speculative visual rewrites.

## Task 20: Run the full verification and produce an evidence matrix

**Files:**

- Modify: `docs/plans/2026-08-30-manual-music-deduplication-review.md` only to append actual command outcomes if the executor uses the plan as a runbook.

**Step 1: Run backend verification**

```bash
dotnet test follow-server/tests/Follow.Core.Tests/Follow.Core.Tests.csproj
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj
```

If shared-output or disposable-service tests interfere, run projects serially and report that choice; never hide skipped integration tests.

**Step 2: Run frontend verification**

```bash
pnpm --dir follow-admin test
pnpm --dir follow-admin build
```

**Step 3: Run configuration and isolated integration verification**

```bash
bash scripts/verify-docker-config.sh
bash scripts/verify-music-import-review.sh
docker compose config >/dev/null
docker compose -f docker-compose.prod.yml config >/dev/null
```

**Step 4: Audit the manual gate and source safety**

```bash
rg -n 'recommendedItemId|Recommendation|decision|Selected' follow-server/src follow-admin/src
rg -n 'Tracks\.Add|PutObject|UploadAsync|RemoveObject|File\.Delete|Directory\.Delete' follow-server/src/Follow.Infrastructure/Services follow-server/src/Follow.Api/Endpoints
rg -n 'absolute|FullPath|RootPath' follow-server/src/Follow.Shared/DTOs follow-server/src/Follow.Api/Endpoints follow-admin/src
```

Review every hit. The only formal Track/object mutations must be inside confirmed apply/replacement paths; mounted-source delete hits must be absent.

**Step 5: Review the complete scoped diff**

```bash
git status --short
git diff --stat
git diff -- docs/plans follow-server follow-admin docker-compose.yml docker-compose.prod.yml .env.example scripts
```

Separate pre-existing user changes from work produced by this plan. Do not stage or commit.

**Step 6: Report proof boundaries**

The completion report must separately state:

- implemented code and migration;
- pure/service test results;
- real `fpcalc` generated-audio calibration result and score margin;
- real disposable PostgreSQL result;
- real disposable MinIO result;
- frontend test/build result;
- local browser interaction result;
- Docker/config result;
- not deployed, not production-migrated, and not production-media-verified.

Do not claim the feature complete if the calibration gate, manual-decision audit, real PostgreSQL/MinIO scenario, or authenticated playback scenario was skipped or failed.

## Final requirement-to-proof matrix

| Requirement | Primary implementation | Required proof |
|---|---|---|
| Same recording across websites/formats can be found | Tasks 3, 4, 7 | generated multi-encoding calibration + grouping E2E |
| Live/remix/cover remain distinct | Tasks 3, 7 | negative score matrix + manual-separate E2E |
| Analyze all before directory review | Tasks 1, 7 | two-phase worker/restart tests |
| Never auto-select | Tasks 1, 2, 9, 14, 15 | domain, API, UI tests + source audit |
| Show quality/format and recommendation | Tasks 2, 5, 13, 15 | recommendation tests + browser QA |
| Browser upload also requires review | Tasks 6, 12, 16 | `202`, no-Track regression test + UI QA |
| Manual replacement preserves identity | Tasks 5, 11 | real PostgreSQL relationship test |
| Safe preview | Task 8 | authorization/range/path tests + browser seeking |
| Restart and concurrency safety | Tasks 7, 9, 10, 11, 18 | PostgreSQL/MinIO restart/race tests |
| No silent SHA-only fallback | Tasks 4, 12, 17 | readiness/config/upload failure tests |
| No production changes | All tasks | final status and target audit |
