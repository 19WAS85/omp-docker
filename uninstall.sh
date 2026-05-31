#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/compose.yaml"

echo "[uninstall.sh] Stopping and removing OMP containers..."
docker compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true

echo "[uninstall.sh] Removing OMP images..."
docker compose -f "$COMPOSE_FILE" down --rmi all 2>/dev/null || true

echo "[uninstall.sh] Removing symlinks..."
rm -f ~/.local/bin/omp
rm -f ~/.local/bin/omp-build
rm -f ~/.local/bin/omp-update

echo "[uninstall.sh] Removing persistent state (~/.omp)..."
rm -rf ~/.omp

echo "[uninstall.sh] Uninstall complete."
