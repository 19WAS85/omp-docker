#!/usr/bin/env bash
set -uo pipefail

if [[ $# -gt 0 ]] && [[ "$1" != "omp" ]] && command -v "$1" &>/dev/null; then
  exec "$@"
fi

[[ "${1:-}" == "omp" ]] && shift

exec omp "$@"
