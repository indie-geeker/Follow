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

FOLLOW_DEV_JSON="$(docker compose -f "$FOLLOW_DEV_COMPOSE" config --format json)"
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

rg -q 'FOLLOW_DEV_COMPOSE=.*docker-compose\.dev\.yml' "$FOLLOW_DEV_COMMAND" ||
  fail 'development command must resolve docker-compose.dev.yml from the repository root'
rg -q '^[[:space:]]*docker compose -f "\$FOLLOW_DEV_COMPOSE" "\$@"' "$FOLLOW_DEV_COMMAND" ||
  fail 'development Compose operations must use the isolated compose helper'
FOLLOW_DOCKER_COMPOSE_CALLS="$(
  rg -c '^[[:space:]]*docker compose([[:space:]]|$)' "$FOLLOW_DEV_COMMAND" || true
)"
[[ "$FOLLOW_DOCKER_COMPOSE_CALLS" == '1' ]] ||
  fail 'development command must route every Compose operation through the isolated compose helper'

if rg -q 'docker-compose\.yml|docker compose (stop|down)' "$FOLLOW_DEV_COMMAND"; then
  fail 'development command must not stop or target the root full stack'
fi

echo 'Development API config checks passed.'
