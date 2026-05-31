#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

echo "[update.sh] Rebuilding image from update stage (base cached)..."
docker compose -f "$SCRIPT_DIR/../compose.yaml" build --build-arg update-token="$(date +%s)"
