# Manual Music Deduplication Review Design

**Date:** 2026-08-30

**Status:** Approved

## Objective

Prevent duplicate recordings across different files, formats, bitrates, metadata, and source websites without allowing the system to decide which file should enter the music library. Directory initialization, later directory imports, and browser uploads must all analyze candidates, explain likely duplicates and quality differences, and wait for an administrator's explicit decision before creating or replacing a Track.

Existing songs are test data and will not be backfilled. The new workflow applies only to later ingestion.

## Duplicate semantics

The system detects the same recording across different encodings or containers. It must preserve different recordings, including live versions, remasters, remixes, covers, accompaniment versions, and materially edited versions.

Signals are layered:

1. SHA-256 proves exact byte equality.
2. A local acoustic fingerprint identifies the same recording after transcoding, tag changes, or container changes.
3. Exact duration and normalized metadata narrow candidates and explain results, but metadata alone never triggers automatic deduplication.

Fingerprint matching is conservative. Uncertain matches remain separate candidates for human review.

## Unified ingestion model

Directory initialization, later directory imports, and browser single-file uploads use the same analysis, grouping, review, and execution services.

The workflow is:

1. Acquire a safe source reference.
2. Validate path, size, modification time, and supported audio policy.
3. Compute SHA-256.
4. Extract metadata and quality information.
5. Compute and persist the acoustic fingerprint and algorithm version.
6. Compare against existing Tracks and other items in the current batch.
7. Build durable suspected-duplicate groups.
8. Calculate a quality recommendation and a human-readable explanation.
9. Enter `AwaitingReview` without creating or replacing a Track.
10. Apply only the administrator's confirmed decisions.
11. Verify object, database, and cleanup outcomes.

The recommendation is advisory. No recommendation can create, replace, skip, or delete a Track without an explicit administrator action.

## Two-phase directory processing

Directory ingestion first analyzes every eligible file and persists each result. It does not keep the whole library in memory. After analysis finishes, a grouping phase compares fingerprints and creates review groups. Formal object storage writes happen only after review.

This prevents filesystem enumeration order from choosing a low-quality MP3 before a higher-quality FLAC. It also makes analysis restart-safe and allows the UI to report analyzed, grouped, reviewed, and imported counts independently.

## Review groups and decisions

Each suspected-duplicate group presents:

- file name and safe relative source path;
- source type and source batch;
- title, artist, album, and other extracted tags;
- codec, container, lossless status, sample rate, bit depth, channels, bitrate, file size, and exact duration;
- exact-hash or acoustic-fingerprint match reason;
- fingerprint similarity and algorithm version;
- the system's quality recommendation and explanation;
- an authenticated preview action.

An administrator can:

- select one candidate to create a new Track;
- select multiple candidates and explicitly mark them as different recordings;
- keep an existing Track and reject new candidates as duplicates;
- replace an existing Track's audio while preserving its identity and relationships;
- defer a group;
- explicitly accept recommendations in bulk, followed by a second confirmation.

Decisions use optimistic versions. Once submitted, a group is locked for execution. A stale page receives a conflict and must refresh.

## Quality recommendation

The system highlights, but never selects, the strongest candidate using deterministic rules:

1. lossless codec over lossy codec;
2. for lossless candidates, useful bit depth and sample rate;
3. for lossy candidates, bitrate;
4. source stability and metadata completeness;
5. safe relative path as a final deterministic tie breaker.

The explanation must name the compared facts, for example, `24-bit / 96 kHz FLAC; higher quality than 320 kbps MP3`.

## Source staging and preview

Mounted directory files remain in the read-only source until the user approves a decision. An admin-only preview endpoint resolves the stored relative path through the existing path policy and supports guarded range streaming without returning an absolute host path.

Browser uploads write to an isolated `tracks/staging/{itemId}/` object path. They do not create Tracks. Review preview streams the staging object through the authenticated API. Cancelled or rejected uploads enter the durable storage-deletion workflow.

If the local fingerprint implementation is unavailable or incompatible, the capability response reports that state and every ingestion entry is disabled. The system must not fall back to importing without acoustic analysis.

## Applying a new Track decision

After confirmation, the worker revalidates the source snapshot, SHA-256, fingerprint, and decision version. It writes the selected audio to a deterministic managed object path, then commits the Track and ingestion result. If the database commit fails, the new object is deleted or recorded for durable cleanup.

Other candidates in the confirmed group become audited duplicates linked to the resulting Track. Source files are never modified or deleted.

## Replacing an existing Track

Replacement preserves the Track ID, playlists, favorites, tags, and play history:

1. Write the selected candidate to a new revision-specific object path.
2. Verify length, SHA-256, and readability.
3. In one database transaction, update the Track media fields and create an audio-revision audit record.
4. Commit the ingestion decision.
5. Queue the old object for deletion only after the database transaction commits.

If the database transaction fails, the new object is cleaned up and the existing Track is unchanged. Failure to delete the old object does not roll back the working replacement; the durable deletion worker retries it and exposes the cleanup state.

## Pause, resume, cancel, and retry

- Pause finishes the current safe unit and prevents new work from being claimed.
- Resume continues from durable analysis, grouping, review, or execution state.
- Cancel stops future work, preserves already committed Tracks, cleans browser staging objects, and never modifies mounted source files.
- Retry is available only for retryable read, fingerprint runtime, storage, database, and cleanup errors.
- A changed source snapshot invalidates stored analysis and fails with `SOURCE_CHANGED` until the administrator explicitly retries or creates a new task.

## Concurrency

Directory processing remains single-worker initially. Browser uploads can overlap, so deduplication is checked before the formal write and again during the final database operation. Concurrent review submissions use group versions; only one decision set can win. A losing upload cleans its staged or newly written object and links to the winning Track when appropriate.

Fingerprint data is compared only within compatible algorithm versions. Algorithm upgrades preserve old version metadata and require an explicit compatibility or recomputation strategy later.

## UI changes

The admin application adds a shared music-ingestion queue and review surface. It displays:

- source readiness and fingerprint-runtime readiness;
- analysis, grouping, review, execution, and verification progress;
- review groups with quality facts and match explanations;
- candidate preview controls;
- explicit keep, replace, separate, reject, defer, and bulk-accept actions;
- conflict, source-changed, fingerprint, storage, database, and cleanup errors.

No page may claim a candidate was selected merely because it is recommended.

## Testing and acceptance

Tests use deterministic generated audio, never copyrighted songs. Fixtures cover the same PCM material encoded to WAV, FLAC, MP3, AAC, and OGG; tag-only changes; volume and ordinary transcoding changes; different waveforms with identical metadata; and synthetic live, remix, cover, and clipped variants.

Verification layers are:

1. pure tests for candidate filtering, fingerprint similarity, quality explanation, and stable ordering;
2. service tests for analysis, grouping, review versions, two-phase execution, pause, resume, cancel, retry, and restart recovery;
3. real PostgreSQL tests for migration and concurrent decisions;
4. real MinIO tests for staging, selected writes, losing-write cleanup, replacement, and deletion retry;
5. real local fingerprint-adapter tests across generated encodings;
6. admin tests for review data, previews, actions, conflicts, and accessibility;
7. an isolated local end-to-end run using a temporary read-only directory and disposable PostgreSQL and MinIO services.

Acceptance requires that no Track is created or replaced before review, the administrator's selection is honored exactly, same-recording candidates are grouped across encodings, different recordings remain distinct, replacement preserves the Track ID and relationships, restart preserves analysis and decisions, and the selected final object plays through the authenticated streaming route.

Production deployment, production migration, and production media validation are explicitly outside this plan until separately authorized.
