#!/usr/bin/env bash
set -uo pipefail

# Clean shutdown on signals
cleanup() {
  exit 0
}
trap cleanup SIGTERM SIGINT

# Known agent commands that should be exec'd directly
KNOWN_COMMANDS=(omp bash sh)

if [[ $# -gt 0 ]]; then
  for cmd in "${KNOWN_COMMANDS[@]}"; do
    if [[ "$1" == "$cmd" ]]; then
      [[ "$1" == "omp" ]] && shift
      exec "$@"
    fi
  done
fi

exec omp "$@"
