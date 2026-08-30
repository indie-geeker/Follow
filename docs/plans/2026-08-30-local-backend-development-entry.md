# Local Backend Development Entry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preserve the root full-stack Docker Compose entry while adding an isolated, documented command for running the ASP.NET Core API locally against Dockerized development dependencies.

**Architecture:** Add a standalone `follow-dev` Compose project containing only PostgreSQL, Redis, and MinIO with loopback-only ports and separate volumes. Add a repository-root command wrapper that validates port ownership and dependency health before running `dotnet watch`, plus an executable configuration contract that prevents Compose, Development settings, and documentation from drifting apart.

**Tech Stack:** Docker Compose, Bash, jq, ASP.NET Core 10, PostgreSQL 18, Redis 8, MinIO.

---

## Working-Tree Safety

The repository already contains extensive unrelated tracked and untracked work. Do not reset, clean, stash, reformat, or stage any file outside the exact file list for the current task. Before every commit, run `git diff --cached --name-only` and confirm that it contains only that task's files.

Do not modify the root `.env`, inspect or print its values, remove the root full-stack volumes, or automatically stop the full-stack services from the development helper.

### Task 1: Add the isolated development dependency contract

**Files:**
- Create: `scripts/verify-dev-api-config.sh`
- Create: `docker-compose.dev.yml`

**Step 1: Write the failing Compose contract check**

Create `scripts/verify-dev-api-config.sh` with the following initial content:

```bash
#!/usr/bin/env bash

set -euo pipefail

FOLLOW_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOLLOW_DEV_COMPOSE="$FOLLOW_REPO_ROOT/docker-compose.dev.yml"
FOLLOW_DEV_SETTINGS="$FOLLOW_REPO_ROOT/follow-server/src/Follow.Api/appsettings.Development.json"

fail() {
  echo "Development API config check failed: $1" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || fail 'docker is required'
command -v jq >/dev/null 2>&1 || fail 'jq is required'
[[ -f "$FOLLOW_DEV_COMPOSE" ]] || fail 'docker-compose.dev.yml is missing'

FOLLOW_DEV_JSON="$(docker compose -f "$FOLLOW_DEV_COMPOSE" config --format json)"

jq -e '
  .name == "follow-dev" and
  (.services | keys | sort) == ["minio", "postgres", "redis"] and
  (.services | all(.build == null))
' <<<"$FOLLOW_DEV_JSON" >/dev/null ||
  fail 'development Compose must be the isolated follow-dev dependency-only project'

jq -e '
  (.services.postgres.ports | any(
    .target == 5432 and .published == "5432" and .host_ip == "127.0.0.1"
  )) and
  (.services.redis.ports | any(
    .target == 6379 and .published == "6379" and .host_ip == "127.0.0.1"
  )) and
  (.services.minio.ports | any(
    .target == 9000 and .published == "9000" and .host_ip == "127.0.0.1"
  )) and
  (.services.minio.ports | any(
    .target == 9001 and .published == "9001" and .host_ip == "127.0.0.1"
  ))
' <<<"$FOLLOW_DEV_JSON" >/dev/null ||
  fail 'every development dependency port must be published on loopback only'

jq -e '
  .services.postgres.environment.POSTGRES_USER == "follow" and
  .services.postgres.environment.POSTGRES_PASSWORD == "follow" and
  .services.postgres.environment.POSTGRES_DB == "follow" and
  .services.minio.environment.MINIO_ROOT_USER == "follow" and
  .services.minio.environment.MINIO_ROOT_PASSWORD == "follow123"
' <<<"$FOLLOW_DEV_JSON" >/dev/null ||
  fail 'development dependency credentials must match Development settings'

jq -e '
  .ConnectionStrings.DefaultConnection == "Host=localhost;Port=5432;Database=follow;Username=follow;Password=follow" and
  .RedisSettings.ConnectionString == "localhost:6379" and
  .MinioSettings.Endpoint == "localhost:9000" and
  .MinioSettings.AccessKey == "follow" and
  .MinioSettings.SecretKey == "follow123" and
  .MinioSettings.UseSSL == false
' "$FOLLOW_DEV_SETTINGS" >/dev/null ||
  fail 'appsettings.Development.json does not match development dependencies'

jq -e '
  (.services.postgres.volumes | any(.type == "volume" and .target == "/var/lib/postgresql")) and
  (.services.redis.volumes | any(.type == "volume" and .target == "/data")) and
  (.services.minio.volumes | any(.type == "volume" and .target == "/data")) and
  (.services.postgres.healthcheck != null) and
  (.services.redis.healthcheck != null) and
  (.services.minio.healthcheck != null)
' <<<"$FOLLOW_DEV_JSON" >/dev/null ||
  fail 'development dependencies require isolated volumes and health checks'

echo 'Development API config checks passed.'
```

Make it executable:

```bash
chmod +x scripts/verify-dev-api-config.sh
```

**Step 2: Run the contract check and verify it fails**

Run:

```bash
bash scripts/verify-dev-api-config.sh
```

Expected: non-zero exit with `docker-compose.dev.yml is missing`.

**Step 3: Add the minimal standalone development Compose file**

Create `docker-compose.dev.yml`:

```yaml
name: follow-dev

services:
  postgres:
    image: postgres:18@sha256:5773fe724c49c42a7a9ca70202e11e1dff21fb7235b335a73f39297d200b73a2
    ports:
      - "127.0.0.1:5432:5432"
    environment:
      POSTGRES_USER: follow
      POSTGRES_PASSWORD: follow
      POSTGRES_DB: follow
    volumes:
      - postgres_data:/var/lib/postgresql
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s

  redis:
    image: redis:8-alpine@sha256:6cbef353e480a8a6e7f10ec545f13d7d3fa85a212cdcc5ffaf5a1c818b9d3798
    command: redis-server --appendonly yes
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

  minio:
    image: minio/minio@sha256:14cea493d9a34af32f524e538b8346cf79f3321eff8e708c1e2960462bd8936e
    command: server /data --console-address ":9001"
    ports:
      - "127.0.0.1:9000:9000"
      - "127.0.0.1:9001:9001"
    environment:
      MINIO_ROOT_USER: follow
      MINIO_ROOT_PASSWORD: follow123
    volumes:
      - minio_data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s

volumes:
  postgres_data:
  redis_data:
  minio_data:
```

Do not add `api` or `admin` services and do not reference the root `.env`.

**Step 4: Run the contract check and verify it passes**

Run:

```bash
bash scripts/verify-dev-api-config.sh
docker compose -f docker-compose.dev.yml config --quiet
```

Expected: `Development API config checks passed.` and both commands exit 0.

**Step 5: Commit only the isolated dependency files**

```bash
git add -- docker-compose.dev.yml scripts/verify-dev-api-config.sh
git diff --cached --check
git diff --cached --name-only
git commit -m "feat: add isolated backend development dependencies"
```

Expected staged paths: only `docker-compose.dev.yml` and `scripts/verify-dev-api-config.sh`.

### Task 2: Add the guarded local API command

**Files:**
- Create: `scripts/dev-api.sh`
- Modify: `scripts/verify-dev-api-config.sh`

**Step 1: Extend the contract check before adding the command**

Append these checks before the success message in `scripts/verify-dev-api-config.sh`:

```bash
FOLLOW_DEV_COMMAND="$FOLLOW_REPO_ROOT/scripts/dev-api.sh"

[[ -x "$FOLLOW_DEV_COMMAND" ]] || fail 'scripts/dev-api.sh is missing or not executable'
bash -n "$FOLLOW_DEV_COMMAND" || fail 'scripts/dev-api.sh has invalid Bash syntax'

for subcommand in run up down status reset; do
  rg -q "^[[:space:]]*$subcommand\\)" "$FOLLOW_DEV_COMMAND" ||
    fail "scripts/dev-api.sh does not handle $subcommand"
done

rg -q 'docker-compose\.dev\.yml' "$FOLLOW_DEV_COMMAND" ||
  fail 'development command must target only docker-compose.dev.yml'

if rg -q 'docker compose (stop|down)|docker-compose\.yml' "$FOLLOW_DEV_COMMAND"; then
  fail 'development command must not stop or target the root full stack'
fi
```

Keep `echo 'Development API config checks passed.'` as the last line.

**Step 2: Run the contract check and verify it fails**

Run:

```bash
bash scripts/verify-dev-api-config.sh
```

Expected: non-zero exit with `scripts/dev-api.sh is missing or not executable`.

**Step 3: Add the minimal guarded command**

Create `scripts/dev-api.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

FOLLOW_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOLLOW_DEV_COMPOSE="$FOLLOW_REPO_ROOT/docker-compose.dev.yml"
FOLLOW_API_PROJECT="$FOLLOW_REPO_ROOT/follow-server/src/Follow.Api"
FOLLOW_API_PORT=5050

fail() {
  echo "Local API startup failed: $1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

compose() {
  docker compose -f "$FOLLOW_DEV_COMPOSE" "$@"
}

require_docker() {
  require_command docker
  docker info >/dev/null 2>&1 || fail 'Docker daemon is not available'
  docker compose version >/dev/null 2>&1 || fail 'Docker Compose is not available'
}

api_port_is_occupied() {
  lsof -nP -iTCP:"$FOLLOW_API_PORT" -sTCP:LISTEN -t >/dev/null 2>&1
}

start_dependencies() {
  require_docker
  compose up -d --wait
}

usage() {
  cat <<'EOF'
Usage: scripts/dev-api.sh <run|up|down|status|reset> [--confirm]

  run      Start healthy development dependencies, then run dotnet watch.
  up       Start development dependencies and wait until they are healthy.
  down     Stop development dependencies and preserve their named volumes.
  status   Show development dependency status.
  reset    Remove development containers and volumes; requires --confirm.
EOF
}

case "${1:-}" in
  run)
    require_command lsof
    if api_port_is_occupied; then
      fail '127.0.0.1:5050 is already in use; stop the full-stack API or choose the Docker workflow'
    fi
    require_command dotnet
    start_dependencies
    cd "$FOLLOW_API_PROJECT"
    exec dotnet watch run --launch-profile http
    ;;
  up)
    start_dependencies
    ;;
  down)
    require_docker
    compose down --remove-orphans
    ;;
  status)
    require_docker
    compose ps
    ;;
  reset)
    [[ "${2:-}" == '--confirm' ]] ||
      fail 'reset deletes follow-dev volumes; rerun with reset --confirm'
    require_docker
    compose down --volumes --remove-orphans
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
```

Make it executable:

```bash
chmod +x scripts/dev-api.sh
```

**Step 4: Verify syntax, safety, and occupied-port behavior**

Run:

```bash
bash -n scripts/dev-api.sh
bash scripts/verify-dev-api-config.sh
scripts/dev-api.sh --help
scripts/dev-api.sh reset
```

Expected:

- Syntax and the configuration contract pass.
- Help lists all five supported commands.
- `reset` without `--confirm` exits non-zero without changing Docker state.

With the current full-stack API still listening on `5050`, run:

```bash
scripts/dev-api.sh run
```

Expected: non-zero exit explaining that `127.0.0.1:5050` is occupied. Confirm with `docker compose ps` that the root services remain running and unchanged.

**Step 5: Commit only the command and its contract update**

```bash
git add -- scripts/dev-api.sh scripts/verify-dev-api-config.sh
git diff --cached --check
git diff --cached --name-only
git commit -m "feat: add guarded local API development command"
```

Expected staged paths: only `scripts/dev-api.sh` and `scripts/verify-dev-api-config.sh`.

### Task 3: Document the two supported workflows

**Files:**
- Modify: `scripts/verify-dev-api-config.sh`
- Modify: `follow-server/README.md`

**Step 1: Add failing documentation assertions**

Before the success message in `scripts/verify-dev-api-config.sh`, add:

```bash
FOLLOW_BACKEND_README="$FOLLOW_REPO_ROOT/follow-server/README.md"

rg -q '^### 完整 Docker 栈$' "$FOLLOW_BACKEND_README" ||
  fail 'README must document the default full Docker stack'
rg -q '^### 本地后端开发$' "$FOLLOW_BACKEND_README" ||
  fail 'README must document the isolated local backend workflow'
rg -q 'scripts/dev-api\.sh run' "$FOLLOW_BACKEND_README" ||
  fail 'README must use the supported local API command'
rg -q 'scripts/dev-api\.sh down' "$FOLLOW_BACKEND_README" ||
  fail 'README must document switching away from development dependencies'
```

**Step 2: Run the contract check and verify it fails**

Run:

```bash
bash scripts/verify-dev-api-config.sh
```

Expected: non-zero exit reporting the first missing README section.

**Step 3: Replace the stale development instructions**

In `follow-server/README.md`, replace the current `### 开发环境` block with:

````markdown
### 完整 Docker 栈

根目录 Compose 是默认入口，启动管理后台、API、PostgreSQL、Redis 和 MinIO：

```bash
cd ..
docker compose up -d --build
```

API 位于 `http://127.0.0.1:5050`，管理后台位于 `http://127.0.0.1:3000`。API 使用 Docker 内部服务名访问依赖；PostgreSQL、Redis 和 MinIO 不发布宿主机端口。使用此模式时不要同时执行 `dotnet run`。

### 本地后端开发

需要断点或热重载时，先停止完整栈；`docker compose down` 默认保留命名卷：

```bash
cd ..
docker compose down
./scripts/dev-api.sh run
```

该命令启动独立的 `follow-dev` PostgreSQL、Redis 和 MinIO，等待健康后通过 `dotnet watch` 启动 API。开发依赖仅发布到 `127.0.0.1`，并使用独立数据卷，不读取根目录 `.env`，也不操作完整栈容器。

常用命令：

```bash
./scripts/dev-api.sh up       # 只启动并等待开发依赖
./scripts/dev-api.sh status   # 查看开发依赖状态
./scripts/dev-api.sh down     # 停止开发依赖，保留数据卷
```

切回完整栈：

```bash
./scripts/dev-api.sh down
docker compose up -d --build
```

仅在确认要清空本地开发数据库和对象存储时执行 `./scripts/dev-api.sh reset --confirm`。
````

Keep the existing production build and deployment sections after this replacement.

**Step 4: Verify the documentation contract passes**

Run:

```bash
bash scripts/verify-dev-api-config.sh
```

Expected: `Development API config checks passed.`

**Step 5: Commit only the README and its contract update**

```bash
git add -- follow-server/README.md scripts/verify-dev-api-config.sh
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: separate full-stack and local API workflows"
```

Expected staged paths: only `follow-server/README.md` and `scripts/verify-dev-api-config.sh`.

### Task 4: Verify the complete workflow without losing data

**Files:**
- Verification only

**Step 1: Run static configuration checks**

Run:

```bash
bash scripts/verify-dev-api-config.sh
docker compose -f docker-compose.dev.yml config --quiet
```

If the existing `scripts/verify-docker-config.sh` is present in this working tree, also run:

```bash
bash scripts/verify-docker-config.sh
```

Expected: all invoked commands exit 0. The root contract continues to report no host-published data-service ports.

**Step 2: Run server tests serially**

Run:

```bash
dotnet test follow-server/tests/Follow.Core.Tests/Follow.Core.Tests.csproj
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj
```

Expected: both commands exit 0 with zero failed tests. Report NuGet vulnerability-feed warnings separately from test failures.

**Step 3: Exercise development dependency lifecycle**

Record the current root stack status, then stop it without deleting volumes:

```bash
docker compose ps
docker compose down
```

Start and inspect the development dependencies:

```bash
scripts/dev-api.sh up
scripts/dev-api.sh status
docker compose -f docker-compose.dev.yml exec -T postgres pg_isready -U follow -d follow
docker compose -f docker-compose.dev.yml exec -T redis redis-cli ping
curl -fsS http://127.0.0.1:9000/minio/health/live
```

Expected: all three services are healthy, PostgreSQL accepts connections, Redis returns `PONG`, and MinIO returns a successful status.

**Step 4: Exercise the host API**

In one terminal run:

```bash
scripts/dev-api.sh run
```

In another terminal run:

```bash
curl -fsS http://127.0.0.1:5050/health
curl -fsS -o /dev/null http://127.0.0.1:5050/swagger/index.html
```

Expected: API startup applies migrations, initializes the MinIO bucket, `/health` succeeds, and Swagger returns success. Capture the API startup output as the database and MinIO connection evidence.

Stop `dotnet watch` with Ctrl-C. Then verify `scripts/dev-api.sh down` preserves the named volumes by running `scripts/dev-api.sh up` again and confirming the same volumes are attached with:

```bash
docker volume ls --filter name=follow-dev
```

**Step 5: Restore and verify the default full stack**

Run:

```bash
scripts/dev-api.sh down
docker compose up -d --build --wait
curl -fsS http://127.0.0.1:5050/health
curl -fsS -o /dev/null http://127.0.0.1:3000/
```

Expected: the default API and admin endpoints succeed, root data-service ports remain unpublished, and the development dependency containers are stopped. Do not use `--volumes` on the root Compose stack.

**Step 6: Audit scope and commits**

Run:

```bash
git status --short
git log --oneline -4
```

Expected implementation paths are limited to:

- `docker-compose.dev.yml`
- `scripts/dev-api.sh`
- `scripts/verify-dev-api-config.sh`
- `follow-server/README.md`

Report the pre-existing unrelated dirty files separately. Do not push, merge, deploy, or remove any volumes.
