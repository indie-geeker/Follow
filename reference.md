# reference.md

This file provides guidance to AI when working with code in this repository.

## Project Overview

Follow Music is a cross-platform music player with three sub-projects in a monorepo:

| Sub-project | Stack | Purpose |
|---|---|---|
| `follow-server/` | .NET 10, ASP.NET Core Minimal API, EF Core, PostgreSQL, Redis, MinIO | Backend API |
| `follow-admin/` | Vue 3, TypeScript, Vite, Element Plus, Pinia | Admin dashboard SPA |
| `follow/` | Flutter (Dart), Riverpod 3, auto_route, just_audio, Freezed | Cross-platform mobile/desktop client |

## Development Commands

### Backend (`follow-server/`)

```bash
# Start dev dependencies (PostgreSQL, Redis, MinIO)
cd follow-server && docker compose up -d

# Database migration
dotnet ef database update --project src/Follow.Infrastructure --startup-project src/Follow.Api

# Run API server (localhost:5000, Swagger at /swagger)
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

# Dev server (localhost:3000)
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
# From repo root - starts API (port 5000) + Admin (port 3000)
docker compose up -d
```

## Architecture

### Backend - Clean/Layered Architecture

- **Follow.Api** - Minimal API endpoints (`Endpoints/`), startup configuration (`Program.cs`)
- **Follow.Core** - Domain entities (`Entities/`) and interfaces (`Interfaces/`)
- **Follow.Infrastructure** - EF Core DbContext (`Data/`), service implementations (`Services/`), migrations
- **Follow.Shared** - DTOs (`DTOs/`) and constants (`Constants/` - roles, policies)

API endpoints are organized as static extension methods in `Endpoints/*.cs` (Auth, Track, Artist, Album, Playlist, UserMusic, Admin, RSS).

Authentication: JWT + Refresh Token. First registered user is auto-promoted to Admin. Two roles: Admin (full management) and Member (playback, favorites, playlists).

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

- Backend dev services: PostgreSQL (5432), Redis (6379), MinIO (9000, console 9001)
- MinIO dev credentials: `follow` / `follow123`
- PostgreSQL dev credentials: `follow` / `follow`
- Docker deployment uses SQLite (via `ConnectionStrings__DefaultConnection=Data Source=/app/data/follow.db`)
- Environment config: `.env.development` / `.env.production` for admin; `appsettings.*.json` for server
- Project language: Chinese comments and documentation throughout
