# Docker Runtime Fix Implementation Plan

> **For Codex:** Use systematic debugging, test-driven development, and verification-before-completion while executing this plan.

**Goal:** Make the repository's root Docker Compose file start the API, PostgreSQL, MinIO, Redis, and admin UI with consistent configuration on an unused host port.

**Architecture:** Treat the root `docker-compose.yml` as the only full-stack entry point. Inject the .NET configuration contract through Compose environment variables, gate API startup on dependency health, build the Vue admin with an explicit public API URL, and keep PostgreSQL/MinIO/Redis data in named volumes.

**Tech Stack:** Docker Compose, ASP.NET Core 10, PostgreSQL 18, MinIO, Redis 8, Vue/Vite, Nginx.

---

### Task 1: Add a Docker configuration regression check

**Files:**
- Create: `scripts/verify-docker-config.sh`

1. Assert that `docker compose config --format json` resolves the API host port to `5050`.
2. Assert that the API receives PostgreSQL, JWT, and MinIO settings under the exact keys read by the code.
3. Assert that PostgreSQL 18 uses `/var/lib/postgresql`, dependencies use health conditions, and the admin build receives `VITE_API_URL`.
4. Run the check before implementation and confirm it fails against the old configuration.

### Task 2: Repair the full-stack container contract

**Files:**
- Modify: `docker-compose.yml`
- Modify: `.env.example`
- Modify: `follow-server/Dockerfile`
- Modify: `follow-admin/Dockerfile`
- Modify: `follow-admin/nginx.conf`

1. Consolidate the complete stack into the root Compose file and remove obsolete SQLite/admin-seed settings.
2. Map host `5050` to API container `5000` and inject matching PostgreSQL, JWT, MinIO, and Redis values.
3. Add dependency health checks and named volumes; mount PostgreSQL 18 at `/var/lib/postgresql`.
4. Use stable .NET 10 images and install curl for the API health check.
5. Pass the public API URL to Vite during image build and raise Nginx's upload size limit.
6. Replace the environment template with the variables actually consumed by Compose.

### Task 3: Verify and run

**Files:**
- Verify only; do not commit unless explicitly requested.

1. Run the regression check and `docker compose config`.
2. Run server and admin build/test gates available in the repository.
3. Build the Docker images and start the stack.
4. Verify container health, API `/health`, database migrations, MinIO readiness, and the admin page.
5. Stop only if verification exposes a concrete blocker; preserve named volumes and unrelated Docker state.
