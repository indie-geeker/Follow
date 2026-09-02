# Playback, Embedded Metadata, and Admin Media Design

**Date:** 2026-08-30

**Status:** Approved

## Problem statement

The same track currently behaves differently across clients:

- The Android player page renders shuffle and repeat icons whose callbacks are empty.
- App-level volume control exists in the audio service and desktop UI but is absent from the mobile player page.
- Managed MP3 objects can contain an embedded cover and timestamped lyrics, while the database only records the extracted cover and leaves `LyricsUrl` empty.
- Flutter treats a missing lyric reference, a failed lyric request, and an unsupported lyric document as the same empty result.
- The packaged Admin application builds a correct same-origin cover URL, but Nginx routes `.jpg` and similar `/api/` requests to its static-file location instead of the API.

The verified sample, `天亮以前说再见`, contains a 480×480 embedded JPEG cover and 61 timestamped lyric entries. Its database row has a valid `CoverUrl` and a null `LyricsUrl`. The direct API cover route returns `200 image/jpeg`; the Docker Admin origin returns `404` for the same object.

## Goals

1. Make Android playback controls use the existing `PlayMode` state model used by desktop.
2. Expose app-level volume and mute controls on the mobile player page.
3. Extract embedded cover art and timestamped lyrics through one server-side metadata path for manual uploads and library initialization.
4. Persist extracted media as managed MinIO objects and keep database references consistent with object writes.
5. Backfill only missing embedded-media references for existing tracks without overwriting administrator uploads.
6. Distinguish truly absent lyrics from request and parsing failures in Flutter.
7. Make cover requests work through both the direct API origin and the packaged Admin origin.
8. Prove the behavior with automated tests and fresh local cross-layer verification.

## Non-goals

- Do not redesign the entire player page or desktop shell.
- Do not introduce independent shuffle and repeat state. `PlayMode.sequence`, `PlayMode.shuffle`, and `PlayMode.single` remain mutually exclusive.
- Do not make Flutter download whole audio files to discover embedded metadata.
- Do not overwrite a non-empty `CoverUrl` or `LyricsUrl` during backfill.
- Do not add a permanent background scheduler or new database tables solely for a one-time backfill.
- Do not deploy, push, modify production data, or run the backfill against existing data without separate authorization.

## Chosen approach

Use a server-owned metadata pipeline and a client-owned presentation pipeline:

1. `IAudioMetadataExtractor` returns title, artist, album, duration, bitrate, format, optional cover bytes, and optional timed-LRC text.
2. A shared embedded-asset writer stores supported cover data and UTF-8 LRC text under managed `covers/{trackId}/...` and `lyrics/{trackId}/...` keys.
3. Both `TrackService.UploadTrackAsync` and `MusicImportProcessor` consume the same extractor and writer.
4. A bounded Admin-only backfill service reads one page of existing managed audio objects, performs a dry run or fills only null media references, and reports per-track results.
5. Flutter uses the existing `PlayerMode` controller and audio volume stream. Missing lyric metadata stays an empty state, while transport and parsing failures remain errors with retry actions.
6. Nginx gives `/api/` precedence over extension-based static caching.

This is preferred over a current-track-only repair because it prevents recurrence, and over client-side tag extraction because it avoids full audio downloads, duplicated parsing, and platform-specific behavior.

## Mobile playback design

The main control row contains one dynamic play-mode button followed by previous,
play/pause, and next; the two independent shuffle/repeat buttons are removed. A
compact secondary volume row contains a mute button that restores the last
non-zero app volume and a horizontal slider bound to `playerVolumeProvider` and
`AudioPlayerService.setVolume`.

The mode button delegates to `playerModeProvider.notifier.nextMode()`. The UI
watches the provider, so the icon immediately reflects state changes made
elsewhere. Applying a mode to just_audio goes through an overridable service
method so tests can verify the state machine without loading the platform audio
plugin. The audio service remembers the last audible value only for mute
restoration; it does not add another playback-mode state.

## Embedded metadata design

`AudioMetadata` is the single extracted representation. Cover extraction accepts JPEG, PNG, WebP, and GIF. Lyrics extraction accepts non-empty text only when it contains at least one valid LRC timestamp. Unsynchronized plain lyrics are reported as unsupported rather than stored as a document the current Flutter UI cannot synchronize.

The asset writer:

- validates the cover MIME type and chooses a safe extension;
- encodes lyric text as UTF-8 and writes it as `text/plain; charset=utf-8`;
- returns the newly created object keys;
- immediately compensates already-written new objects if a later asset write fails;
- allows callers to request cover-only, lyrics-only, or both so backfill never overwrites existing references.

The database row is updated only with object keys returned by a successful write. If the database update fails, the caller compensates all newly created embedded assets. Existing deletion-outbox behavior remains responsible for replacing administrator-uploaded media, but backfill never queues or deletes existing media.

## Historical backfill design

Add a bounded Admin-only operation with `dryRun`, `afterId`, and `limit` inputs. The service selects tracks where `CoverUrl` or `LyricsUrl` is null, ordered by ID for stable pagination.

For each track it:

1. checks the managed audio object metadata;
2. copies the object into an isolated temporary seekable file without exposing MinIO publicly;
3. extracts metadata;
4. reports which missing assets are available during dry-run;
5. during execution, writes only assets whose database fields are still null;
6. rechecks the row before saving so a concurrent manual upload wins;
7. compensates any new object that became unnecessary or whose database save failed;
8. records success, skipped, unsupported, and failed outcomes in the response.

Each request handles a small bounded page. Retrying the same page is safe because non-null references are skipped. No automatic startup backfill is allowed.

## Lyrics state and error handling

Flutter uses three distinct outcomes:

- `lyricsUrl` absent: `AsyncData([])` and “暂无歌词”.
- lyrics document fetched and parsed: synchronized lyric lines.
- request failure, missing referenced object, or zero valid timed lines: `AsyncError` and a visible “歌词加载失败，重试” action.

`LyricsService` must not catch every exception and convert it to an empty list. It throws a typed format error for an invalid LRC document and lets Dio failures propagate. Both the mobile page and desktop lyric overlay provide retry by invalidating `currentTrackLyricsProvider`.

## Admin media routing

The packaged Nginx configuration uses `location ^~ /api/` so regex locations for `.jpg`, `.png`, and other static extensions are not considered for API requests. Static asset caching remains unchanged for real frontend assets.

Verification must exercise a cover URL through the Admin origin, not only test URL string construction or the direct API endpoint.

## Testing strategy

- Flutter widget tests verify the single dynamic mode control, mode transitions, volume changes, mute restoration, 48dp touch targets, and absence of the two dead controls.
- Flutter service/widget tests verify missing, parsed, failed, and retry lyric states.
- Core and API tests use a small synthetic tagged audio fixture, never copyrighted music, to verify cover and timed-lyric extraction.
- Infrastructure tests verify embedded-asset write compensation and database/object consistency in both upload paths.
- Backfill tests verify dry-run, missing-only writes, stable pagination, concurrent manual-upload precedence, retry safety, and per-track failure isolation.
- Admin contract tests verify Nginx API precedence; local runtime verification confirms the same cover is `200 image/jpeg` through ports 5050 and 3000.

## Safety and rollout boundaries

- Preserve the current dirty tree and stage only named files if commits are later authorized.
- Run all automated checks before touching the local runtime stack.
- Rebuild or restart local Docker services only during the explicit runtime-verification phase.
- Run backfill in dry-run mode first and review counts and per-track outcomes.
- Execute the real backfill only after separate user authorization.
- Report implementation, automated tests, local Docker verification, backfill dry-run, backfill execution, deployment, and production verification as separate statuses.
