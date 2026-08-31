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
  docker compose --env-file /dev/null -f "$FOLLOW_DEV_COMPOSE" "$@"
}

require_docker() {
  require_command docker
  docker info >/dev/null 2>&1 || fail 'Docker daemon is not available'
  compose version >/dev/null 2>&1 || fail 'Docker Compose is not available'
}

api_port_is_occupied() {
  local lsof_output
  local lsof_exit=0

  lsof_output="$(
    lsof -nP -iTCP:"$FOLLOW_API_PORT" -sTCP:LISTEN -t 2>&1
  )" || lsof_exit=$?

  if [[ "$lsof_exit" -eq 0 ]]; then
    return 0
  fi
  if [[ "$lsof_exit" -eq 1 && -z "$lsof_output" ]]; then
    return 1
  fi

  if [[ -n "$lsof_output" ]]; then
    fail "could not determine whether 127.0.0.1:$FOLLOW_API_PORT is available (lsof exit $lsof_exit): $lsof_output"
  fi
  fail "could not determine whether 127.0.0.1:$FOLLOW_API_PORT is available (lsof exit $lsof_exit)"
}

require_compose_wait() {
  local compose_up_help

  if ! compose_up_help="$(compose up --help 2>&1)"; then
    fail 'could not inspect Docker Compose up capabilities'
  fi
  if [[ "$compose_up_help" =~ (^|[[:space:]])--wait([=[:space:]]|$) ]]; then
    return
  fi
  fail 'Docker Compose up does not support --wait'
}

start_dependencies() {
  require_docker
  require_compose_wait
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
  run|up|down|status)
    [[ "$#" -eq 1 ]] || fail "$1 does not accept additional arguments"
    ;;
esac

case "${1:-}" in
  run)
    require_command lsof
    if api_port_is_occupied; then
      fail '127.0.0.1:5050 is already in use; stop the full-stack API or choose the Docker workflow'
    fi
    require_command dotnet
    start_dependencies
    if api_port_is_occupied; then
      fail '127.0.0.1:5050 is already in use; stop the full-stack API or choose the Docker workflow'
    fi
    cd "$FOLLOW_API_PROJECT"
    AdminAccount__Username='admin' \
      AdminAccount__Email='admin@follow.local' \
      AdminAccount__Password='FollowDev!123' \
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
    [[ "$#" -eq 2 && "${2:-}" == '--confirm' ]] ||
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
