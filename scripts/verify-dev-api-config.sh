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
