# Local Backend Development Entry Design

## Goal

Keep the repository-root `docker-compose.yml` as the default full-stack entry point while adding an explicit, isolated workflow for running the ASP.NET Core API on the host with PostgreSQL, Redis, and MinIO in Docker.

The development workflow must avoid sharing credentials or data volumes with the full stack, expose dependencies only on host loopback, detect the API port conflict before startup, and leave unrelated containers and working-tree changes untouched.

## Selected Approach

Add a standalone `docker-compose.dev.yml` for development dependencies and a `scripts/dev-api.sh` command wrapper.

The root Compose contract remains unchanged:

```text
docker compose up -d --build
  -> api + admin + postgres + redis + minio
  -> API published on 127.0.0.1:5050
  -> dependency ports remain private to Docker
```

The local backend workflow is separate:

```text
scripts/dev-api.sh run
  -> validates that 127.0.0.1:5050 is available
  -> starts follow-dev postgres, redis, and minio
  -> waits for dependency health
  -> runs dotnet watch against Follow.Api
```

## Development Dependency Stack

`docker-compose.dev.yml` contains only PostgreSQL, Redis, and MinIO. It uses a distinct Compose project name and distinct named volumes so local migrations, seed data, and uploaded objects cannot affect the default full stack.

Published ports are loopback-only:

| Service | Host endpoint | Purpose |
| --- | --- | --- |
| PostgreSQL | `127.0.0.1:5432` | EF Core migrations and API database access |
| Redis | `127.0.0.1:6379` | API cache and runtime coordination |
| MinIO API | `127.0.0.1:9000` | API object-storage access |
| MinIO console | `127.0.0.1:9001` | Optional local inspection |

The stack uses fixed development-only credentials that match `appsettings.Development.json`. They are safe only because every published port is bound to loopback. Root `.env` values are not loaded or copied into this workflow.

Health checks remain equivalent to the full-stack checks. The local API is not started until all three dependencies report healthy.

## Development Command

`scripts/dev-api.sh` is the supported entry point. It resolves paths relative to the repository rather than the caller's working directory and supports:

- `run`: validate prerequisites, start dependencies, wait for health, then run `dotnet watch`.
- `up`: start dependencies and wait for health without starting the API.
- `down`: stop and remove only development containers and networks while preserving named volumes.
- `status`: display development dependency status.
- `reset`: intentionally remove development containers and development volumes after an explicit confirmation flag. This is the only destructive subcommand.

Before `run`, the script checks whether TCP port `5050` is already listening. If the full-stack API or another process owns the port, the script exits with an actionable message. It does not stop or alter the full stack automatically.

The script also checks for `docker`, Docker daemon availability, and `dotnet`. Errors identify the failed prerequisite or unhealthy dependency and include the corresponding inspection command.

## Configuration Contract

The host API continues to load `appsettings.Development.json` through its existing launch profile. Development dependency hostnames remain `localhost`, and the API continues to listen on `http://localhost:5050`.

The following values must stay synchronized between `docker-compose.dev.yml` and `appsettings.Development.json`:

- PostgreSQL database, username, password, and port.
- Redis port and connection string.
- MinIO endpoint, access key, secret key, bucket name, and SSL setting.

A configuration verification script checks this contract without starting containers. This prevents the current failure mode in which documentation, Compose networking, and application configuration disagree.

## Documentation and Switching Workflows

The backend README presents the two workflows separately:

1. Full stack: use root `docker compose up -d --build`; do not also run `dotnet run` on port `5050`.
2. Local backend development: stop the full stack or at least its API, then use `scripts/dev-api.sh run`.

Switching back to the full stack first runs `scripts/dev-api.sh down`, then starts the root Compose stack. Neither direction removes named volumes by default.

The README explains that container service names such as `postgres` work only inside Docker networks, while host processes must use published `localhost` ports.

## Verification

Automated checks cover:

1. Root `docker-compose.yml` still resolves as the complete default stack and does not publish PostgreSQL, Redis, or MinIO ports.
2. `docker-compose.dev.yml` contains only dependency services, uses isolated volumes, and binds every published port to `127.0.0.1`.
3. Development Compose credentials and endpoints match `appsettings.Development.json`.
4. The command wrapper rejects an occupied API port and never stops full-stack services automatically.
5. Shell syntax and repository server tests remain valid.

Manual verification covers:

1. Start the development dependencies and confirm all health checks pass.
2. Start the API with `scripts/dev-api.sh run` and verify `/health` and Swagger on `127.0.0.1:5050`.
3. Exercise a database-backed route and a MinIO-backed route.
4. Stop development dependencies without deleting volumes, restart them, and confirm data persists.
5. Stop the development workflow, start the default full stack, and verify its API and admin health independently.

## Alternatives Rejected

An override of the root Compose file would reuse full-stack credentials and volumes, making local migrations and test data affect the default stack. A single Compose file with profiles would make the default command less obvious and conflict with the requirement that the complete stack remain the default entry point.
