#!/usr/bin/env bash
set -uo pipefail

# Clean shutdown on signals
cleanup() {
  exit 0
}
trap cleanup SIGTERM SIGINT

# If arguments are provided, exec them directly.
# This handles: entrypoint omp, entrypoint bash, entrypoint sh, etc.
if [[ $# -gt 0 ]]; then
  exec "$@"
fi

# Default: run the agent
exec omp
