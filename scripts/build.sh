#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

echo "[build.sh] Building..."
docker compose -f "$SCRIPT_DIR/../compose.yaml" build "$@"
