#!/usr/bin/env bash

set -euo pipefail

FOLLOW_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOLLOW_DEV_COMPOSE="$FOLLOW_REPO_ROOT/docker-compose.dev.yml"
FOLLOW_ROOT_COMPOSE="$FOLLOW_REPO_ROOT/docker-compose.yml"
FOLLOW_DEV_SETTINGS="$FOLLOW_REPO_ROOT/follow-server/src/Follow.Api/appsettings.Development.json"

fail() {
  echo "Development API config check failed: $1" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || fail 'docker is required'
command -v jq >/dev/null 2>&1 || fail 'jq is required'
command -v rg >/dev/null 2>&1 || fail 'rg is required'
[[ -f "$FOLLOW_DEV_COMPOSE" ]] || fail 'docker-compose.dev.yml is missing'

FOLLOW_DEV_JSON="$(
  docker compose --env-file /dev/null -f "$FOLLOW_DEV_COMPOSE" config --format json
)"
FOLLOW_ROOT_JSON="$(
  docker compose --env-file /dev/null -f "$FOLLOW_ROOT_COMPOSE" \
    config --format json --no-interpolate
)"

FOLLOW_DEV_COMPOSE_CONTRACT='
  def exact_images($root):
    ([
      .services.postgres.image,
      .services.redis.image,
      .services.minio.image
    ] | all(type == "string" and test("@sha256:[0-9a-f]{64}$"))) and
    ([
      $root.services.postgres.image,
      $root.services.redis.image,
      $root.services.minio.image
    ] | all(type == "string")) and
    .services.postgres.image == $root.services.postgres.image and
    .services.redis.image == $root.services.redis.image and
    .services.minio.image == $root.services.minio.image;

  def published_ports:
    [
      .services | to_entries[] as $service |
      ($service.value.ports // [])[] |
      {
        service: $service.key,
        host_ip: .host_ip,
        target: .target,
        published: .published
      }
    ] | sort_by([.service, .target, .published]);

  def exact_ports:
    published_ports == [
      {service: "minio", host_ip: "127.0.0.1", target: 9000, published: "9000"},
      {service: "minio", host_ip: "127.0.0.1", target: 9001, published: "9001"},
      {service: "postgres", host_ip: "127.0.0.1", target: 5432, published: "5432"},
      {service: "redis", host_ip: "127.0.0.1", target: 6379, published: "6379"}
    ];

  def resolved_mounts($service):
    . as $document |
    [
      $document.services[$service].volumes[]? as $mount |
      {
        type: $mount.type,
        source: $document.volumes[$mount.source].name,
        target: $mount.target
      }
    ];

  def exact_volumes:
    (.volumes | keys | sort) == ["minio_data", "postgres_data", "redis_data"] and
    (.volumes | all((.external // false) == false)) and
    .volumes.postgres_data.name == "follow-dev_postgres_data" and
    .volumes.redis_data.name == "follow-dev_redis_data" and
    .volumes.minio_data.name == "follow-dev_minio_data" and
    resolved_mounts("postgres") == [
      {type: "volume", source: "follow-dev_postgres_data", target: "/var/lib/postgresql"}
    ] and
    resolved_mounts("redis") == [
      {type: "volume", source: "follow-dev_redis_data", target: "/data"}
    ] and
    resolved_mounts("minio") == [
      {type: "volume", source: "follow-dev_minio_data", target: "/data"}
    ];

  def exact_healthchecks:
    .services.postgres.healthcheck == {
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"],
      timeout: "5s",
      interval: "5s",
      retries: 10,
      start_period: "10s"
    } and
    .services.redis.healthcheck == {
      test: ["CMD", "redis-cli", "ping"],
      timeout: "3s",
      interval: "5s",
      retries: 10
    } and
    .services.minio.healthcheck == {
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"],
      timeout: "5s",
      interval: "5s",
      retries: 10,
      start_period: "10s"
    };

  def development_compose_contract($root):
    .name == "follow-dev" and
    (.services | keys | sort) == ["minio", "postgres", "redis"] and
    (.services | all(.build == null and .restart == "unless-stopped")) and
    exact_images($root) and
    exact_ports and
    exact_volumes and
    exact_healthchecks;

  development_compose_contract($root)
'

compose_contract_passes() {
  jq -e --argjson root "$FOLLOW_ROOT_JSON" "$FOLLOW_DEV_COMPOSE_CONTRACT" \
    <<<"$1" >/dev/null
}

assert_contract_rejects() {
  local variant_name="$1"
  local variant_json="$2"

  if compose_contract_passes "$variant_json"; then
    fail "development Compose contract accepted $variant_name"
  fi
}

compose_contract_passes "$FOLLOW_DEV_JSON" ||
  fail 'development Compose must exactly match the isolated dependency contract'

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

FOLLOW_EXTRA_PORT_JSON="$(jq '
  .services.postgres.ports += [{
    mode: "ingress",
    host_ip: "0.0.0.0",
    target: 5432,
    published: "15432",
    protocol: "tcp"
  }]
' <<<"$FOLLOW_DEV_JSON")"
assert_contract_rejects 'an extra publicly bound port' "$FOLLOW_EXTRA_PORT_JSON"

FOLLOW_EXTERNAL_VOLUME_JSON="$(jq '
  .volumes.postgres_data = {
    name: "production_postgres_data",
    external: true
  }
' <<<"$FOLLOW_DEV_JSON")"
assert_contract_rejects 'an external production data volume' "$FOLLOW_EXTERNAL_VOLUME_JSON"

FOLLOW_WRONG_VOLUME_SOURCE_JSON="$(jq '
  .services.postgres.volumes[0].source = "redis_data"
' <<<"$FOLLOW_DEV_JSON")"
assert_contract_rejects 'a service using another dependency volume' "$FOLLOW_WRONG_VOLUME_SOURCE_JSON"

FOLLOW_DISABLED_HEALTHCHECK_JSON="$(jq '
  .services.postgres.healthcheck = {disable: true}
' <<<"$FOLLOW_DEV_JSON")"
assert_contract_rejects 'a disabled health check' "$FOLLOW_DISABLED_HEALTHCHECK_JSON"

FOLLOW_NONE_HEALTHCHECK_JSON="$(jq '
  .services.redis.healthcheck = {test: ["NONE"]}
' <<<"$FOLLOW_DEV_JSON")"
assert_contract_rejects 'a NONE health check' "$FOLLOW_NONE_HEALTHCHECK_JSON"

FOLLOW_NOOP_HEALTHCHECK_JSON="$(jq '
  .services.minio.healthcheck = {test: ["CMD", "true"]}
' <<<"$FOLLOW_DEV_JSON")"
assert_contract_rejects 'a no-op health check' "$FOLLOW_NOOP_HEALTHCHECK_JSON"

FOLLOW_UNPINNED_IMAGE_JSON="$(jq '
  .services.redis.image = "redis:8-alpine"
' <<<"$FOLLOW_DEV_JSON")"
assert_contract_rejects 'an unpinned dependency image' "$FOLLOW_UNPINNED_IMAGE_JSON"

FOLLOW_DRIFTED_IMAGE_JSON="$(jq '
  .services.redis.image = "redis:8-alpine@sha256:0000000000000000000000000000000000000000000000000000000000000000"
' <<<"$FOLLOW_DEV_JSON")"
assert_contract_rejects 'a dependency image that differs from the root Compose' "$FOLLOW_DRIFTED_IMAGE_JSON"

FOLLOW_DEV_COMMAND="$FOLLOW_REPO_ROOT/scripts/dev-api.sh"

[[ -x "$FOLLOW_DEV_COMMAND" ]] || fail 'scripts/dev-api.sh is missing or not executable'
bash -n "$FOLLOW_DEV_COMMAND" || fail 'scripts/dev-api.sh has invalid Bash syntax'

for subcommand in run up down status reset; do
  rg -q "^[[:space:]]*$subcommand\\)" "$FOLLOW_DEV_COMMAND" ||
    fail "scripts/dev-api.sh does not handle $subcommand"
done

FOLLOW_PORT_GUARD_MATCH="$(
  rg -n -m 1 '^[[:space:]]*if api_port_is_occupied; then' "$FOLLOW_DEV_COMMAND" || true
)"
FOLLOW_PORT_CONFLICT_MATCH="$(
  rg -n -m 1 "fail '127\\.0\\.0\\.1:5050 is already in use;" "$FOLLOW_DEV_COMMAND" || true
)"
FOLLOW_DOTNET_REQUIRE_MATCH="$(
  rg -n -m 1 '^[[:space:]]*require_command dotnet$' "$FOLLOW_DEV_COMMAND" || true
)"
[[ -n "$FOLLOW_PORT_GUARD_MATCH" && -n "$FOLLOW_PORT_CONFLICT_MATCH" && -n "$FOLLOW_DOTNET_REQUIRE_MATCH" ]] ||
  fail 'run must define the API port conflict guard and dotnet prerequisite'
FOLLOW_PORT_GUARD_LINE="${FOLLOW_PORT_GUARD_MATCH%%:*}"
FOLLOW_PORT_CONFLICT_LINE="${FOLLOW_PORT_CONFLICT_MATCH%%:*}"
FOLLOW_DOTNET_REQUIRE_LINE="${FOLLOW_DOTNET_REQUIRE_MATCH%%:*}"
[[ "$FOLLOW_PORT_GUARD_LINE" -lt "$FOLLOW_PORT_CONFLICT_LINE" &&
  "$FOLLOW_PORT_CONFLICT_LINE" -lt "$FOLLOW_DOTNET_REQUIRE_LINE" ]] ||
  fail 'run must report an occupied API port before requiring dotnet'

rg -q 'FOLLOW_DEV_COMPOSE=.*docker-compose\.dev\.yml' "$FOLLOW_DEV_COMMAND" ||
  fail 'development command must resolve docker-compose.dev.yml from the repository root'
rg -q '^[[:space:]]*docker compose --env-file /dev/null -f "\$FOLLOW_DEV_COMPOSE" "\$@"' "$FOLLOW_DEV_COMMAND" ||
  fail 'development Compose operations must use the isolated compose helper'
FOLLOW_DOCKER_COMPOSE_CALLS="$(
  rg -c '^[[:space:]]*docker compose([[:space:]]|$)' "$FOLLOW_DEV_COMMAND" || true
)"
[[ "$FOLLOW_DOCKER_COMPOSE_CALLS" == '1' ]] ||
  fail 'development command must route every Compose operation through the isolated compose helper'

if rg -q 'docker-compose\.yml|docker compose (stop|down)' "$FOLLOW_DEV_COMMAND"; then
  fail 'development command must not stop or target the root full stack'
fi

FOLLOW_COMMAND_TEST_ROOT="$(
  mktemp -d "${TMPDIR:-/tmp}/follow-dev-api-command.XXXXXX"
)" || fail 'could not create the command contract test directory'
FOLLOW_TEST_BIN="$FOLLOW_COMMAND_TEST_ROOT/bin"
FOLLOW_TEST_MINIMAL_BIN="$FOLLOW_COMMAND_TEST_ROOT/minimal-bin"
FOLLOW_TEST_DOCKER_LOG="$FOLLOW_COMMAND_TEST_ROOT/docker.log"
FOLLOW_TEST_LSOF_LOG="$FOLLOW_COMMAND_TEST_ROOT/lsof.log"
FOLLOW_TEST_LSOF_COUNTER="$FOLLOW_COMMAND_TEST_ROOT/lsof.count"
FOLLOW_TEST_DOTNET_LOG="$FOLLOW_COMMAND_TEST_ROOT/dotnet.log"
FOLLOW_TEST_OUTPUT="$FOLLOW_COMMAND_TEST_ROOT/command.out"
mkdir -p "$FOLLOW_TEST_BIN" "$FOLLOW_TEST_MINIMAL_BIN"
trap 'rm -rf -- "$FOLLOW_COMMAND_TEST_ROOT"' EXIT

cat >"$FOLLOW_TEST_BIN/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

{
  printf '%s' "${1:-}"
  shift || true
  for argument in "$@"; do
    printf '\t%s' "$argument"
  done
  printf '\n'
} >>"$FOLLOW_TEST_DOCKER_LOG"

if [[ "$*" == "--env-file /dev/null -f $FOLLOW_TEST_DEV_COMPOSE up --help" ]]; then
  if [[ "$FOLLOW_TEST_WAIT_MODE" == 'supported' ]]; then
    echo '      --wait            Wait for services to be running|healthy'
  else
    echo 'Usage: docker compose up [OPTIONS] [SERVICE...]'
    echo '      --wait-timeout duration'
  fi
fi
EOF

cat >"$FOLLOW_TEST_BIN/lsof" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

{
  printf '%s' "${1:-}"
  shift || true
  for argument in "$@"; do
    printf '\t%s' "$argument"
  done
  printf '\n'
} >>"$FOLLOW_TEST_LSOF_LOG"

follow_lsof_count=0
if [[ -f "$FOLLOW_TEST_LSOF_COUNTER" ]]; then
  read -r follow_lsof_count <"$FOLLOW_TEST_LSOF_COUNTER"
fi
follow_lsof_count=$((follow_lsof_count + 1))
printf '%s\n' "$follow_lsof_count" >"$FOLLOW_TEST_LSOF_COUNTER"

case "$FOLLOW_TEST_LSOF_MODE" in
  occupied)
    echo '4242'
    exit 0
    ;;
  free)
    exit 1
    ;;
  free-then-occupied)
    if [[ "$follow_lsof_count" -eq 1 ]]; then
      exit 1
    fi
    echo '4242'
    exit 0
    ;;
  rc2)
    exit 2
    ;;
  error-output)
    echo 'simulated lsof diagnostic' >&2
    exit 1
    ;;
  *)
    echo "unknown fake lsof mode: $FOLLOW_TEST_LSOF_MODE" >&2
    exit 2
    ;;
esac
EOF

cat >"$FOLLOW_TEST_BIN/dotnet" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

{
  printf '%s' "${1:-}"
  shift || true
  for argument in "$@"; do
    printf '\t%s' "$argument"
  done
  printf '\n'
} >>"$FOLLOW_TEST_DOTNET_LOG"
EOF

chmod +x "$FOLLOW_TEST_BIN/docker" "$FOLLOW_TEST_BIN/lsof" "$FOLLOW_TEST_BIN/dotnet"
ln -s /bin/bash "$FOLLOW_TEST_MINIMAL_BIN/bash"
ln -s /usr/bin/dirname "$FOLLOW_TEST_MINIMAL_BIN/dirname"
ln -s "$FOLLOW_TEST_BIN/lsof" "$FOLLOW_TEST_MINIMAL_BIN/lsof"
for minimal_command in bash dirname lsof; do
  PATH="$FOLLOW_TEST_MINIMAL_BIN" command -v "$minimal_command" >/dev/null 2>&1 ||
    fail "minimal port-priority PATH is missing $minimal_command"
done
if PATH="$FOLLOW_TEST_MINIMAL_BIN" command -v docker >/dev/null 2>&1 ||
  PATH="$FOLLOW_TEST_MINIMAL_BIN" command -v dotnet >/dev/null 2>&1; then
  fail 'minimal port-priority PATH must not contain docker or dotnet'
fi

reset_command_test_logs() {
  : >"$FOLLOW_TEST_DOCKER_LOG"
  : >"$FOLLOW_TEST_LSOF_LOG"
  : >"$FOLLOW_TEST_DOTNET_LOG"
  : >"$FOLLOW_TEST_OUTPUT"
  rm -f "$FOLLOW_TEST_LSOF_COUNTER"
}

run_command_test() {
  local lsof_mode="$1"
  local wait_mode="$2"
  shift 2

  (
    export PATH="$FOLLOW_TEST_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
    export FOLLOW_TEST_DOCKER_LOG FOLLOW_TEST_LSOF_LOG FOLLOW_TEST_LSOF_COUNTER
    export FOLLOW_TEST_DOTNET_LOG
    export FOLLOW_TEST_DEV_COMPOSE="$FOLLOW_DEV_COMPOSE"
    export FOLLOW_TEST_LSOF_MODE="$lsof_mode"
    export FOLLOW_TEST_WAIT_MODE="$wait_mode"
    "$FOLLOW_DEV_COMMAND" "$@"
  ) >"$FOLLOW_TEST_OUTPUT" 2>&1
}

run_port_priority_test() {
  (
    export PATH="$FOLLOW_TEST_MINIMAL_BIN"
    export FOLLOW_TEST_LSOF_LOG FOLLOW_TEST_LSOF_COUNTER
    export FOLLOW_TEST_LSOF_MODE='occupied'
    "$FOLLOW_DEV_COMMAND" run
  ) >"$FOLLOW_TEST_OUTPUT" 2>&1
}

assert_command_exit() {
  local expected_exit="$1"
  local actual_exit="$2"
  local scenario="$3"

  [[ "$actual_exit" -eq "$expected_exit" ]] ||
    fail "$scenario exited $actual_exit instead of $expected_exit: $(<"$FOLLOW_TEST_OUTPUT")"
}

assert_log_equals() {
  local expected_log="$1"
  local log_path="$2"
  local scenario="$3"
  local actual_log
  actual_log="$(<"$log_path")"

  [[ "$actual_log" == "$expected_log" ]] ||
    fail "$scenario recorded unexpected argv; expected [$expected_log], got [$actual_log]"
}

assert_rejected_without_docker() {
  local scenario="$1"
  shift
  local command_exit=0

  reset_command_test_logs
  run_command_test free supported "$@" || command_exit=$?
  [[ "$command_exit" -ne 0 ]] || fail "$scenario must be rejected"
  assert_log_equals '' "$FOLLOW_TEST_DOCKER_LOG" "$scenario"
}

assert_rejected_without_prerequisites() {
  local scenario="$1"
  shift
  local command_exit=0

  reset_command_test_logs
  run_command_test free supported "$@" || command_exit=$?
  [[ "$command_exit" -ne 0 ]] || fail "$scenario must be rejected"
  assert_log_equals '' "$FOLLOW_TEST_DOCKER_LOG" "$scenario"
  assert_log_equals '' "$FOLLOW_TEST_LSOF_LOG" "$scenario"
  assert_log_equals '' "$FOLLOW_TEST_DOTNET_LOG" "$scenario"
}

FOLLOW_EXPECT_DOCKER_STATUS="$(
  printf 'info\ncompose\t--env-file\t/dev/null\t-f\t%s\tversion\ncompose\t--env-file\t/dev/null\t-f\t%s\tps' \
    "$FOLLOW_DEV_COMPOSE" "$FOLLOW_DEV_COMPOSE"
)"
FOLLOW_EXPECT_DOCKER_DOWN="$(
  printf 'info\ncompose\t--env-file\t/dev/null\t-f\t%s\tversion\ncompose\t--env-file\t/dev/null\t-f\t%s\tdown\t--remove-orphans' \
    "$FOLLOW_DEV_COMPOSE" "$FOLLOW_DEV_COMPOSE"
)"
FOLLOW_EXPECT_DOCKER_UP="$(
  printf 'info\ncompose\t--env-file\t/dev/null\t-f\t%s\tversion\ncompose\t--env-file\t/dev/null\t-f\t%s\tup\t--help\ncompose\t--env-file\t/dev/null\t-f\t%s\tup\t-d\t--wait' \
    "$FOLLOW_DEV_COMPOSE" "$FOLLOW_DEV_COMPOSE" "$FOLLOW_DEV_COMPOSE"
)"
FOLLOW_EXPECT_DOCKER_UP_WITHOUT_WAIT="$(
  printf 'info\ncompose\t--env-file\t/dev/null\t-f\t%s\tversion\ncompose\t--env-file\t/dev/null\t-f\t%s\tup\t--help' \
    "$FOLLOW_DEV_COMPOSE" "$FOLLOW_DEV_COMPOSE"
)"
FOLLOW_EXPECT_DOCKER_RESET="$(
  printf 'info\ncompose\t--env-file\t/dev/null\t-f\t%s\tversion\ncompose\t--env-file\t/dev/null\t-f\t%s\tdown\t--volumes\t--remove-orphans' \
    "$FOLLOW_DEV_COMPOSE" "$FOLLOW_DEV_COMPOSE"
)"
FOLLOW_EXPECT_LSOF_CALL="$(
  printf '%s\t%s\t%s\t%s' '-nP' '-iTCP:5050' '-sTCP:LISTEN' '-t'
)"
FOLLOW_EXPECT_LSOF_TWICE="$(
  printf '%s\n%s' "$FOLLOW_EXPECT_LSOF_CALL" "$FOLLOW_EXPECT_LSOF_CALL"
)"
FOLLOW_EXPECT_DOTNET_RUN="$(
  printf '%s\t%s\t%s\t%s' 'watch' 'run' '--launch-profile' 'http'
)"

reset_command_test_logs
command_exit=0
run_command_test free supported --help || command_exit=$?
assert_command_exit 0 "$command_exit" 'help'
assert_log_equals '' "$FOLLOW_TEST_DOCKER_LOG" 'help'

reset_command_test_logs
command_exit=0
run_command_test free supported unknown || command_exit=$?
assert_command_exit 2 "$command_exit" 'unknown command'
assert_log_equals '' "$FOLLOW_TEST_DOCKER_LOG" 'unknown command'

for strict_subcommand in run up down status; do
  assert_rejected_without_prerequisites \
    "$strict_subcommand with a trailing argument" "$strict_subcommand" unexpected
  assert_rejected_without_prerequisites \
    "$strict_subcommand with a trailing help argument" "$strict_subcommand" --help
done

reset_command_test_logs
command_exit=0
run_command_test free supported status || command_exit=$?
assert_command_exit 0 "$command_exit" 'status'
assert_log_equals "$FOLLOW_EXPECT_DOCKER_STATUS" "$FOLLOW_TEST_DOCKER_LOG" 'status'

reset_command_test_logs
command_exit=0
run_command_test free supported down || command_exit=$?
assert_command_exit 0 "$command_exit" 'down'
assert_log_equals "$FOLLOW_EXPECT_DOCKER_DOWN" "$FOLLOW_TEST_DOCKER_LOG" 'down'

reset_command_test_logs
command_exit=0
run_command_test free supported up || command_exit=$?
assert_command_exit 0 "$command_exit" 'up'
assert_log_equals "$FOLLOW_EXPECT_DOCKER_UP" "$FOLLOW_TEST_DOCKER_LOG" 'up'

reset_command_test_logs
command_exit=0
run_command_test free unsupported up || command_exit=$?
assert_command_exit 1 "$command_exit" 'up without --wait support'
assert_log_equals "$FOLLOW_EXPECT_DOCKER_UP_WITHOUT_WAIT" "$FOLLOW_TEST_DOCKER_LOG" 'up without --wait support'
rg -q 'Docker Compose up does not support --wait' "$FOLLOW_TEST_OUTPUT" ||
  fail 'up without --wait support must explain the missing capability'

assert_rejected_without_docker 'reset without confirmation' reset
assert_rejected_without_docker 'reset with wrong confirmation' reset nope
assert_rejected_without_docker 'reset with a trailing argument' reset --confirm extra
assert_rejected_without_docker 'reset with a trailing help argument' reset --confirm --help

reset_command_test_logs
command_exit=0
run_command_test free supported reset --confirm || command_exit=$?
assert_command_exit 0 "$command_exit" 'confirmed reset'
assert_log_equals "$FOLLOW_EXPECT_DOCKER_RESET" "$FOLLOW_TEST_DOCKER_LOG" 'confirmed reset'

reset_command_test_logs
command_exit=0
run_command_test occupied supported run || command_exit=$?
assert_command_exit 1 "$command_exit" 'run with an occupied API port'
assert_log_equals '' "$FOLLOW_TEST_DOCKER_LOG" 'run with an occupied API port'
assert_log_equals '' "$FOLLOW_TEST_DOTNET_LOG" 'run with an occupied API port'
assert_log_equals "$FOLLOW_EXPECT_LSOF_CALL" "$FOLLOW_TEST_LSOF_LOG" 'run with an occupied API port'

reset_command_test_logs
command_exit=0
run_port_priority_test || command_exit=$?
assert_command_exit 1 "$command_exit" 'occupied API port without docker or dotnet'
rg -q '127\.0\.0\.1:5050 is already in use' "$FOLLOW_TEST_OUTPUT" ||
  fail 'occupied API port without docker or dotnet must report the port conflict'
if rg -q '(docker|dotnet) is required' "$FOLLOW_TEST_OUTPUT"; then
  fail 'occupied API port without docker or dotnet must not report a prerequisite failure'
fi
assert_log_equals '' "$FOLLOW_TEST_DOCKER_LOG" 'occupied API port without docker or dotnet'
assert_log_equals '' "$FOLLOW_TEST_DOTNET_LOG" 'occupied API port without docker or dotnet'
assert_log_equals "$FOLLOW_EXPECT_LSOF_CALL" "$FOLLOW_TEST_LSOF_LOG" 'occupied API port without docker or dotnet'

for lsof_failure_mode in rc2 error-output; do
  reset_command_test_logs
  command_exit=0
  run_command_test "$lsof_failure_mode" supported run || command_exit=$?
  assert_command_exit 1 "$command_exit" "run with lsof failure $lsof_failure_mode"
  assert_log_equals '' "$FOLLOW_TEST_DOCKER_LOG" "run with lsof failure $lsof_failure_mode"
  assert_log_equals '' "$FOLLOW_TEST_DOTNET_LOG" "run with lsof failure $lsof_failure_mode"
  rg -q 'could not determine whether 127\.0\.0\.1:5050 is available' "$FOLLOW_TEST_OUTPUT" ||
    fail "run with lsof failure $lsof_failure_mode must explain the port probe failure"
done

reset_command_test_logs
command_exit=0
run_command_test free supported run || command_exit=$?
assert_command_exit 0 "$command_exit" 'run with an available API port'
assert_log_equals "$FOLLOW_EXPECT_DOCKER_UP" "$FOLLOW_TEST_DOCKER_LOG" 'run with an available API port'
assert_log_equals "$FOLLOW_EXPECT_LSOF_TWICE" "$FOLLOW_TEST_LSOF_LOG" 'run with an available API port'
assert_log_equals "$FOLLOW_EXPECT_DOTNET_RUN" "$FOLLOW_TEST_DOTNET_LOG" 'run with an available API port'

reset_command_test_logs
command_exit=0
run_command_test free-then-occupied supported run || command_exit=$?
assert_command_exit 1 "$command_exit" 'run when the API port becomes occupied'
assert_log_equals "$FOLLOW_EXPECT_DOCKER_UP" "$FOLLOW_TEST_DOCKER_LOG" 'run when the API port becomes occupied'
assert_log_equals "$FOLLOW_EXPECT_LSOF_TWICE" "$FOLLOW_TEST_LSOF_LOG" 'run when the API port becomes occupied'
assert_log_equals '' "$FOLLOW_TEST_DOTNET_LOG" 'run when the API port becomes occupied'
rg -q '127\.0\.0\.1:5050 is already in use' "$FOLLOW_TEST_OUTPUT" ||
  fail 'run when the API port becomes occupied must report the conflict'

echo 'Development API config checks passed.'
