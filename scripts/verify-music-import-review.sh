#!/usr/bin/env bash

set -euo pipefail

FOLLOW_IMPORT_OBJECT_PATH='follow-server/src/Follow.Infrastructure/Storage/ImportObjectPath.cs'
if [[ ! -f "$FOLLOW_IMPORT_OBJECT_PATH" ]]; then
  echo "Isolated integration check failed: required source is missing: $FOLLOW_IMPORT_OBJECT_PATH" >&2
  exit 1
fi
if git check-ignore -q "$FOLLOW_IMPORT_OBJECT_PATH"; then
  echo "Isolated integration check failed: required source is ignored by Git: $FOLLOW_IMPORT_OBJECT_PATH" >&2
  exit 1
fi

FOLLOW_RUN_ID="$(date +%s)-$$"
FOLLOW_POSTGRES_CONTAINER="follow-import-postgres-$FOLLOW_RUN_ID"
FOLLOW_MINIO_CONTAINER="follow-import-minio-$FOLLOW_RUN_ID"
FOLLOW_POSTGRES_USER='follow_test'
FOLLOW_POSTGRES_PASSWORD='follow-test-postgres-password'
FOLLOW_POSTGRES_DB='postgres'
FOLLOW_MINIO_ACCESS_KEY='followtest'
FOLLOW_MINIO_SECRET_KEY='follow-test-minio-password'
FOLLOW_LOG_DIR='tmp/music-import-review'
FOLLOW_LOG_PATH="$FOLLOW_LOG_DIR/run-$FOLLOW_RUN_ID.log"

cleanup() {
  docker stop "$FOLLOW_MINIO_CONTAINER" >/dev/null 2>&1 || true
  docker stop "$FOLLOW_POSTGRES_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

mkdir -p "$FOLLOW_LOG_DIR"

docker run --rm -d \
  --name "$FOLLOW_POSTGRES_CONTAINER" \
  -e "POSTGRES_USER=$FOLLOW_POSTGRES_USER" \
  -e "POSTGRES_PASSWORD=$FOLLOW_POSTGRES_PASSWORD" \
  -e "POSTGRES_DB=$FOLLOW_POSTGRES_DB" \
  -p 127.0.0.1::5432 \
  postgres:18@sha256:5773fe724c49c42a7a9ca70202e11e1dff21fb7235b335a73f39297d200b73a2 \
  >/dev/null

docker run --rm -d \
  --name "$FOLLOW_MINIO_CONTAINER" \
  -e "MINIO_ROOT_USER=$FOLLOW_MINIO_ACCESS_KEY" \
  -e "MINIO_ROOT_PASSWORD=$FOLLOW_MINIO_SECRET_KEY" \
  -p 127.0.0.1::9000 \
  minio/minio@sha256:14cea493d9a34af32f524e538b8346cf79f3321eff8e708c1e2960462bd8936e \
  server /data \
  >/dev/null

FOLLOW_POSTGRES_PORT="$(docker port "$FOLLOW_POSTGRES_CONTAINER" 5432/tcp | sed -n 's/.*://p' | tail -1)"
FOLLOW_MINIO_PORT="$(docker port "$FOLLOW_MINIO_CONTAINER" 9000/tcp | sed -n 's/.*://p' | tail -1)"
if [[ ! "$FOLLOW_POSTGRES_PORT" =~ ^[0-9]+$ ]] || [[ ! "$FOLLOW_MINIO_PORT" =~ ^[0-9]+$ ]]; then
  echo 'Isolated integration check failed: Docker did not publish loopback test ports.' >&2
  exit 1
fi

for _ in {1..60}; do
  if docker exec "$FOLLOW_POSTGRES_CONTAINER" \
    pg_isready -U "$FOLLOW_POSTGRES_USER" -d "$FOLLOW_POSTGRES_DB" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! docker exec "$FOLLOW_POSTGRES_CONTAINER" \
  pg_isready -U "$FOLLOW_POSTGRES_USER" -d "$FOLLOW_POSTGRES_DB" >/dev/null 2>&1; then
  echo 'Isolated integration check failed: disposable PostgreSQL did not become ready.' >&2
  exit 1
fi

for _ in {1..60}; do
  if curl -fsS "http://127.0.0.1:$FOLLOW_MINIO_PORT/minio/health/live" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! curl -fsS "http://127.0.0.1:$FOLLOW_MINIO_PORT/minio/health/live" >/dev/null; then
  echo 'Isolated integration check failed: disposable MinIO did not become ready.' >&2
  exit 1
fi

FOLLOW_TEST_POSTGRES="Host=127.0.0.1;Port=$FOLLOW_POSTGRES_PORT;Database=$FOLLOW_POSTGRES_DB;Username=$FOLLOW_POSTGRES_USER;Password=$FOLLOW_POSTGRES_PASSWORD;Pooling=false" \
FOLLOW_TEST_MINIO_ENDPOINT="127.0.0.1:$FOLLOW_MINIO_PORT" \
FOLLOW_TEST_MINIO_ACCESS_KEY="$FOLLOW_MINIO_ACCESS_KEY" \
FOLLOW_TEST_MINIO_SECRET_KEY="$FOLLOW_MINIO_SECRET_KEY" \
dotnet test follow-server/tests/Follow.Api.Tests/Follow.Api.Tests.csproj \
  --no-restore \
  --filter 'FullyQualifiedName~MusicImportEndToEndTests|FullyQualifiedName~MusicImportRestartRecoveryTests|FullyQualifiedName~MusicImportReviewConcurrencyTests|FullyQualifiedName~MusicImportApplyServiceTests|FullyQualifiedName~MusicImportReplacementTests|FullyQualifiedName~MusicImportBrowserUploadTests|FullyQualifiedName~StorageDeletionWorkerTests|FullyQualifiedName~TrackStreamingTests|FullyQualifiedName~TrackUploadReviewRoutingTests' \
  --logger 'console;verbosity=normal' \
  2>&1 | tee "$FOLLOW_LOG_PATH"

echo "Isolated music-import review checks passed. Log: $FOLLOW_LOG_PATH"
