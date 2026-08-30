#!/usr/bin/env bash

set -euo pipefail

FOLLOW_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOLLOW_DEV_COMPOSE="$FOLLOW_REPO_ROOT/docker-compose.dev.yml"
FOLLOW_API_PROJECT="$FOLLOW_REPO_ROOT/follow-server/src/Follow.Api"
FOLLOW_API_PORT=5050

fail() {
  echo "Local API command failed: $1" >&2
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
  compose version >/dev/null 2>&1 || fail 'Docker Compose is not available'
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

The reset command deletes the follow-dev named volumes only when invoked as:
  scripts/dev-api.sh reset --confirm
EOF
}

case "${1:-}" in
  run)
    require_command lsof
    require_command dotnet
    if api_port_is_occupied; then
      fail '127.0.0.1:5050 is already in use; stop the full-stack API or choose the Docker workflow'
    fi
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
