# reference.md

This file provides guidance to AI when working with code in this repository.

## Project Overview

Follow Music is a family music library and player with three sub-projects in a monorepo. The product boundary is household music management, personal libraries, playlists, and playback across trusted devices.

| Sub-project | Stack | Purpose |
|---|---|---|
| `follow-server/` | .NET 10, ASP.NET Core Minimal API, EF Core, PostgreSQL, Redis, MinIO | Backend API |
| `follow-admin/` | Vue 3, TypeScript, Vite, Element Plus, Pinia | Admin dashboard SPA |
| `follow/` | Flutter (Dart), Riverpod 3, auto_route, just_audio, Freezed | Cross-platform mobile/desktop client |

## Development Commands

### Backend (`follow-server/`)

```bash
# Start dev dependencies (PostgreSQL, Redis, MinIO) from the repo root
cp .env.example .env  # first run only; replace every placeholder
docker compose up -d postgres redis minio

# Database migration
dotnet ef database update --project follow-server/src/Follow.Infrastructure --startup-project follow-server/src/Follow.Api

# Run API server (localhost:5050, Swagger at /swagger)
dotnet run --project follow-server/src/Follow.Api

# Run tests
dotnet test follow-server/tests/Follow.Api.Tests
dotnet test follow-server/tests/Follow.Core.Tests

# Publish for production
dotnet publish follow-server/src/Follow.Api -c Release -o ./publish
```

### Admin Dashboard (`follow-admin/`)

```bash
# Install dependencies (uses pnpm)
cd follow-admin && pnpm install

# Start Vite development server
pnpm dev

# Type-check and build
pnpm build
```

### Flutter Client (`follow/`)

```bash
# Get dependencies
cd follow && flutter pub get

# Code generation (Freezed models, Riverpod providers, auto_route)
dart run build_runner build --delete-conflicting-outputs

# Run app
flutter run
```

### Full Stack via Docker

```bash
# From repo root - starts the complete stack
docker compose up -d --build
```

## Architecture

### Backend - Clean/Layered Architecture

- **Follow.Api** - Minimal API endpoints (`Endpoints/`), startup configuration (`Program.cs`)
- **Follow.Core** - Domain entities (`Entities/`) and interfaces (`Interfaces/`)
- **Follow.Infrastructure** - EF Core DbContext (`Data/`), service implementations (`Services/`), migrations
- **Follow.Shared** - DTOs (`DTOs/`) and constants (`Constants/` - roles, policies)

API endpoints are organized as static extension methods in `Endpoints/*.cs` (Auth, Track, Artist, Album, Playlist, UserMusic, Admin, Tag).

Authentication uses JWT access tokens plus per-device `UserSession` refresh rotation. Access tokens carry `sid`, and every authenticated request verifies that the session is still active. The Web admin uses same-origin Secure/HttpOnly/Strict cookies and receives no JSON tokens; Flutter receives body tokens and stores them in platform secure storage. Public registration always creates a Member; the environment-managed account is the Admin.

Session lifecycle endpoints are `POST /api/auth/logout`, `POST /api/auth/logout-all`, `GET /api/auth/sessions`, and `DELETE /api/auth/sessions/{id}`. Logout revokes server state immediately; clearing client state alone is not a valid logout implementation. Register, login, refresh, normal API traffic, uploads, and concurrent streams have separate rate limits and use `429` plus `Retry-After` when rejected.

Media playback uses `GET`/`HEAD /api/tracks/{id}/stream` with single-range `200`/`206`/`416` semantics and direct object-to-response copying. MinIO is private infrastructure. The anonymous cover proxy only accepts managed image keys under `covers/`, `artists/`, or `albums/`; audio, lyrics, and arbitrary keys require authenticated resource endpoints.

Database/object consistency uses transactional metadata writes, upload compensation, and durable `StorageDeletionJob` records processed by `StorageDeletionWorker`. Playlist writes are owner-only, public playlists are read-only to non-owners, DTOs expose `ownerId`/`ownerName`/`isOwnedByCurrentUser`/`canEdit`, reorder accepts only a complete unique permutation, and pagination-capable list queries must stay bounded and stably ordered.

### Admin Dashboard - Vue 3 SPA

- Path alias: `@/` maps to `src/`
- State: Pinia store in `stores/auth.ts`
- API client: Axios instance in `api/index.ts`
- Route guards enforce authentication; public route is only `/login`
- Layout wrapper in `layouts/AdminLayout.vue`

### Flutter Client - Feature-First MVVM

- **`lib/features/`** - Feature modules (auth, home, player, library, search, downloads, settings)
- **`lib/data/models/`** - Freezed immutable data classes (require code generation)
- **`lib/data/providers/`** - Riverpod providers (auth, track, audio, download)
- **`lib/data/services/`** - API and local services (Dio-based)
- **`lib/core/`** - Config, Material 3 theming, localization, extensions
- **`lib/shared/widgets/`** - Reusable widgets (mini_player, track_tile)
- **`lib/router/`** - auto_route navigation setup

Code generation is required after modifying models, providers, or routes: `dart run build_runner build --delete-conflicting-outputs`

## Key Dev Environment Details

- The local Docker stack binds API `5050` and Admin `3000` to host loopback only; PostgreSQL, Redis, and MinIO have no host ports.
- Android Emulator Debug uses `http://10.0.2.2:5050` without run arguments. Release clients must use an explicit public HTTPS origin, and production must place an HTTPS reverse proxy in front of the loopback Admin endpoint.
- MinIO and PostgreSQL credentials come from the root `.env` file.
- Docker and local development both use PostgreSQL; Docker persists data in named volumes.
- Admin API calls are relative `/api` requests; Vite proxies them only during development. Server configuration remains in `appsettings.*.json` and root Compose environment variables.
- Project language: Chinese comments and documentation throughout
