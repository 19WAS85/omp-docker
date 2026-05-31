#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
export OMP_WORKDIR="$PWD"
# Ensure ~/.gitconfig exists so the bind mount in compose.yaml works
[[ -f "$HOME/.gitconfig" ]] || touch "$HOME/.gitconfig"

# Host env vars (TERM, LANG, HTTP_PROXY, etc.) are forwarded to the container
# via bare-name passthrough in compose.yaml's environment: section.
COMPOSE_FILE="$SCRIPT_DIR/compose.yaml"
exec docker compose -f "$COMPOSE_FILE" run --rm omp "$@"
