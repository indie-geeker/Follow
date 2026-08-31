#!/usr/bin/env bash

set -euo pipefail

FOLLOW_TEST_POSTGRES_PASSWORD='test-postgres-password'
FOLLOW_TEST_POSTGRES_USER='test-postgres-user'
FOLLOW_TEST_POSTGRES_DB='test-postgres-db'
FOLLOW_TEST_JWT_SECRET='test-jwt-secret-at-least-32-characters-long'
FOLLOW_TEST_MINIO_USER='test-minio-user'
FOLLOW_TEST_MINIO_PASSWORD='test-minio-password'
FOLLOW_TEST_ADMIN_USERNAME='test-admin'
FOLLOW_TEST_ADMIN_EMAIL='test-admin@example.com'
FOLLOW_TEST_ADMIN_PASSWORD='TestAdminStrong!2026'
FOLLOW_TEST_IMPORT_SOURCE_PATH='/contract-only/follow-music-library'

FOLLOW_COMPOSE_ENV=(
  "POSTGRES_PASSWORD=$FOLLOW_TEST_POSTGRES_PASSWORD"
  "POSTGRES_USER=$FOLLOW_TEST_POSTGRES_USER"
  "POSTGRES_DB=$FOLLOW_TEST_POSTGRES_DB"
  "JWT_SECRET=$FOLLOW_TEST_JWT_SECRET"
  "MINIO_ROOT_USER=$FOLLOW_TEST_MINIO_USER"
  "MINIO_ROOT_PASSWORD=$FOLLOW_TEST_MINIO_PASSWORD"
  "ADMIN_USERNAME=$FOLLOW_TEST_ADMIN_USERNAME"
  "ADMIN_EMAIL=$FOLLOW_TEST_ADMIN_EMAIL"
  "ADMIN_PASSWORD=$FOLLOW_TEST_ADMIN_PASSWORD"
)

FOLLOW_COMPOSE_JSON="$(
  env "${FOLLOW_COMPOSE_ENV[@]}" \
    docker compose config --format json
)"

FOLLOW_IMPORT_COMPOSE_JSON="$(
  env "${FOLLOW_COMPOSE_ENV[@]}" \
    "FOLLOW_IMPORT_SOURCE_PATH=$FOLLOW_TEST_IMPORT_SOURCE_PATH" \
    docker compose \
      -f docker-compose.yml \
      -f docker-compose.import.yml \
      config --format json
)"

FOLLOW_PROD_COMPOSE_JSON="$(
  env "${FOLLOW_COMPOSE_ENV[@]}" \
    "FOLLOW_IMPORT_SOURCE_PATH=$FOLLOW_TEST_IMPORT_SOURCE_PATH" \
    docker compose -f docker-compose.prod.yml config --format json
)"

assert_compose() {
  local expression="$1"
  local message="$2"

  if ! jq -e "$expression" <<<"$FOLLOW_COMPOSE_JSON" >/dev/null; then
    echo "Docker config check failed: $message" >&2
    exit 1
  fi
}

assert_import_compose() {
  local expression="$1"
  local message="$2"

  if ! jq -e "$expression" <<<"$FOLLOW_IMPORT_COMPOSE_JSON" >/dev/null; then
    echo "Docker import config check failed: $message" >&2
    exit 1
  fi
}

assert_prod_compose() {
  local expression="$1"
  local message="$2"

  if ! jq -e "$expression" <<<"$FOLLOW_PROD_COMPOSE_JSON" >/dev/null; then
    echo "Docker production config check failed: $message" >&2
    exit 1
  fi
}

assert_compose \
  '(.services | has("gateway") | not) and
   (.services | has("api") and has("admin") and has("postgres") and has("redis") and has("minio"))' \
  'root Compose must define the five local services without a bundled gateway'

assert_compose \
  '[.services[] | (.volumes // [])[] | select((.target // "") | startswith("/imports"))] | length == 0' \
  'base Compose must not mount the opt-in import source'

if env "${FOLLOW_COMPOSE_ENV[@]}" \
  FOLLOW_IMPORT_SOURCE_PATH='' \
  docker compose \
    -f docker-compose.yml \
    -f docker-compose.import.yml \
    config --quiet >/dev/null 2>&1; then
  echo 'Docker import config check failed: overlay must require FOLLOW_IMPORT_SOURCE_PATH' >&2
  exit 1
fi

assert_import_compose \
  '(.services | has("import-worker") | not) and
   .services.api.environment.MusicImport__Enabled == "true" and
   .services.api.environment.MusicImport__SourceRoot == "/imports/library"' \
  'the API-hosted worker must be explicitly enabled against the mounted source root'

assert_import_compose \
  '([.services[] | (.volumes // [])[] | select((.target // "") | startswith("/imports"))] | length) == 1 and
   (.services.api.volumes | any(
     .type == "bind" and
     .source == "/contract-only/follow-music-library" and
     .target == "/imports/library" and
     .read_only == true and
     .bind.create_host_path == false
   ))' \
  'overlay must bind exactly one existing host library to /imports/library read-only without creating it'

assert_prod_compose \
  '(.services.api.volumes | any(
     .source == "/contract-only/follow-music-library" and
     .target == "/imports/library" and
     .read_only == true and
     .bind.create_host_path == false
   ))' \
  'production Compose must include the explicit read-only import overlay'

assert_compose \
  '.services.api.environment.AudioFingerprint__ExecutablePath == "/usr/local/bin/fpcalc" and
   .services.api.environment.AudioFingerprint__RequiredVersionPrefix == "1.6.1" and
   .services.api.environment.AudioFingerprint__Algorithm == "2" and
   .services.api.environment.AudioFingerprint__MaximumLengthSeconds == "120" and
   .services.api.environment.AudioFingerprint__TimeoutSeconds == "30" and
   .services.api.environment.AudioFingerprint__MaximumStandardOutputBytes == "2097152" and
   .services.api.environment.AudioFingerprint__MaximumStandardErrorBytes == "16384"' \
  'API fingerprint executable, exact version, algorithm, and process bounds must be explicit'

assert_compose \
  '.services.api.healthcheck.test[-1] == "http://localhost:5000/health/ready"' \
  'API container readiness must fail closed through the fingerprint-aware endpoint'

assert_compose \
  '[.services.postgres.image, .services.redis.image, .services.minio.image] |
   all(test("@sha256:[0-9a-f]{64}$"))' \
  'external runtime images must be pinned by immutable digest'

assert_compose \
  '(.services.api.ports | any(
     .target == 5000 and .published == "5050" and .host_ip == "127.0.0.1"
   )) and
   (.services.admin.ports | any(
     .target == 80 and .published == "3000" and .host_ip == "127.0.0.1"
   ))' \
  'API and Admin must publish only the documented host-loopback development ports'

if rg -q '^FOLLOW_(HTTP|HTTPS)_PORT=' .env.example; then
  echo 'Docker config check failed: non-standard public ports break canonical HTTPS redirects' >&2
  exit 1
fi

assert_compose \
  '.networks.web.internal == true and .networks.data.internal == true and
   ((.networks.local.internal // false) == false) and
   (.networks | has("public") | not) and (.networks | has("proxy") | not) and
   (.services.api.networks | has("local") and has("web") and has("data")) and
   (.services.admin.networks | has("local") and has("web")) and
   (.services.admin.networks | has("data") | not) and
   (.services.minio.networks | has("data")) and
   (.services.minio.networks | has("web") | not)' \
  'Admin/API and data services must retain separate internal networks'

assert_compose \
  '((.services.postgres.ports // []) | length) == 0 and
   ((.services.redis.ports // []) | length) == 0 and
   ((.services.minio.ports // []) | length) == 0' \
  'data services must not publish host ports'

assert_compose \
  '.services.api.environment.ConnectionStrings__DefaultConnection == "Host=postgres;Port=5432;Database=test-postgres-db;Username=test-postgres-user;Password=test-postgres-password"' \
  'API must use the PostgreSQL service name and injected database credentials'

assert_compose \
  '.services.postgres.environment.POSTGRES_USER == "test-postgres-user" and
   .services.postgres.environment.POSTGRES_DB == "test-postgres-db" and
   .services.postgres.environment.POSTGRES_PASSWORD == "test-postgres-password"' \
  'PostgreSQL must receive the injected user, database, and password'

assert_compose \
  '.services.api.environment.JwtSettings__SecretKey == "test-jwt-secret-at-least-32-characters-long"' \
  'JWT secret must use the JwtSettings key consumed by the API'

assert_compose \
  '.services.api.environment.AdminAccount__Username == "test-admin" and
   .services.api.environment.AdminAccount__Email == "test-admin@example.com" and
   .services.api.environment.AdminAccount__Password == "TestAdminStrong!2026"' \
  'API must receive the configured bootstrap administrator account'

assert_compose \
  '.services.api.environment.MinioSettings__Endpoint == "minio:9000" and
   .services.api.environment.MinioSettings__AccessKey == "test-minio-user" and
   .services.api.environment.MinioSettings__SecretKey == "test-minio-password"' \
  'MinIO settings must point at the internal service with matching credentials'

assert_compose \
  '.services.api.depends_on.postgres.condition == "service_healthy" and
   .services.api.depends_on.minio.condition == "service_healthy"' \
  'API must wait for PostgreSQL and MinIO readiness'

assert_compose \
  '.services.postgres.volumes | any(.target == "/var/lib/postgresql")' \
  'PostgreSQL 18 data must be mounted at /var/lib/postgresql'

assert_compose \
  '((.services.admin.build.args // {}) | has("VITE_API_URL")) | not' \
  'admin must not embed a browser-visible API origin at build time'

if ! rg -q '^FROM mcr\.microsoft\.com/dotnet/sdk:10\.0@sha256:[0-9a-f]{64} AS build$' follow-server/Dockerfile ||
  ! rg -q '^FROM mcr\.microsoft\.com/dotnet/aspnet:10\.0@sha256:[0-9a-f]{64} AS final$' follow-server/Dockerfile ||
  ! rg -q '^FROM node:20-alpine@sha256:[0-9a-f]{64} AS builder$' follow-admin/Dockerfile ||
  ! rg -q '^FROM nginx:alpine@sha256:[0-9a-f]{64} AS production$' follow-admin/Dockerfile; then
  echo 'Docker config check failed: build/runtime base images must use stable versions pinned by digest' >&2
  exit 1
fi

if ! rg -q '^ARG CHROMAPRINT_VERSION=1\.6\.1$' follow-server/Dockerfile ||
  ! rg -q '^ARG CHROMAPRINT_AMD64_SHA256=[0-9a-f]{64}$' follow-server/Dockerfile ||
  ! rg -q '^ARG CHROMAPRINT_ARM64_SHA256=[0-9a-f]{64}$' follow-server/Dockerfile ||
  ! rg -q 'sha256sum -c -' follow-server/Dockerfile ||
  ! rg -q 'fpcalc -version' follow-server/Dockerfile ||
  ! rg -q 'ffmpeg -version' follow-server/Dockerfile; then
  echo 'Docker config check failed: fpcalc and FFmpeg runtimes must be pinned and build-verified' >&2
  exit 1
fi

if rg -q '^ARG VITE_API_URL$|^ENV VITE_API_URL=' follow-admin/Dockerfile; then
  echo 'Docker config check failed: admin Dockerfile must not embed VITE_API_URL' >&2
  exit 1
fi

if [[ -e Caddyfile ]]; then
  echo 'Docker config check failed: the local stack must not include a Caddy configuration' >&2
  exit 1
fi

if rg -q '^RUN npm (ci|run build)$' follow-admin/Dockerfile ||
  ! rg -q 'pnpm install --frozen-lockfile' follow-admin/Dockerfile ||
  ! rg -q 'pnpm run build' follow-admin/Dockerfile; then
  echo 'Docker config check failed: admin Dockerfile must build with the committed pnpm lockfile' >&2
  exit 1
fi

if ! rg -q 'client_max_body_size 500M;' follow-admin/nginx.conf ||
  ! rg -q 'location \^~ /api/ \{' follow-admin/nginx.conf ||
  ! rg -q 'proxy_pass http://api:5000' follow-admin/nginx.conf; then
  echo 'Docker config check failed: admin Nginx must prioritize same-origin API proxying and allow 500M uploads' >&2
  exit 1
fi

if ! rg -q '^node_modules/?$' follow-admin/.dockerignore 2>/dev/null ||
  ! rg -q '^bin/?$' follow-server/.dockerignore 2>/dev/null ||
  ! rg -q '^obj/?$' follow-server/.dockerignore 2>/dev/null; then
  echo 'Docker config check failed: Docker contexts must exclude host build artifacts' >&2
  exit 1
fi

if rg -n 'localhost:5000' \
  follow-admin/src \
  follow-admin/.env.development \
  follow-server/src/Follow.Api/Properties/launchSettings.json \
  follow-server/scripts/verify-auth-response.sh \
  follow/lib >/dev/null; then
  echo 'Docker config check failed: application defaults must not reference the occupied host port 5000' >&2
  exit 1
fi

if rg -q 'VITE_API_URL' follow-admin/.env.development follow-admin/.env.production 2>/dev/null; then
  echo 'Docker config check failed: admin environment files must not define a browser API origin' >&2
  exit 1
fi

if ! rg -q "https://localhost" follow/lib/core/config/app_config.dart; then
  echo 'Docker config check failed: Flutter production-safe default must remain HTTPS' >&2
  exit 1
fi

if ! rg -q "http://10.0.2.2:5050" follow/lib/core/config/app_config.dart ||
  ! rg -q "http://localhost:5050" follow/lib/core/config/app_config.dart ||
  ! rg -q 'cleartextTrafficPermitted="true"' follow/android/app/src/debug/res/xml/network_security_config.xml ||
  ! rg -q '>10.0.2.2</domain>' follow/android/app/src/debug/res/xml/network_security_config.xml; then
  echo 'Docker config check failed: Android Emulator debug must use the direct loopback API exception' >&2
  exit 1
fi

if rg -q 'cleartextTrafficPermitted="true"' \
  follow/android/app/src/main/res/xml/network_security_config.xml \
  follow/android/app/src/profile/res/xml/network_security_config.xml; then
  echo 'Docker config check failed: Android Profile and Release must remain HTTPS-only' >&2
  exit 1
fi

if [[ -e scripts/prepare-android-emulator.sh ]] ||
  rg -n 'LOCAL_CA_PEM_BASE64|configureLocalTlsTrust|localhost:8443' \
  follow/lib \
  follow/README.md \
  follow-server/docs/deployment-guide.md >/dev/null; then
  echo 'Docker config check failed: retired Caddy, CA, ADB reverse, or wrong-emulator paths remain' >&2
  exit 1
fi

if rg -n 'http://10\.0\.0\.2' follow/lib >/dev/null; then
  echo 'Docker config check failed: Flutter code must not use the wrong emulator host alias' >&2
  exit 1
fi

if ! rg -q '"applicationUrl": "http://localhost:5050"' follow-server/src/Follow.Api/Properties/launchSettings.json; then
  echo 'Docker config check failed: local API launch profile must use host port 5050' >&2
  exit 1
fi

if ! rg -q '^ADMIN_USERNAME=' .env.example ||
  ! rg -q '^ADMIN_EMAIL=' .env.example ||
  ! rg -q '^ADMIN_PASSWORD=' .env.example; then
  echo 'Docker config check failed: .env.example must document the administrator account' >&2
  exit 1
fi

echo 'Docker config checks passed.'
