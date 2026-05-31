#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

echo "[install.sh] Building Docker image..."
docker compose -f "$SCRIPT_DIR/compose.yaml" build

mkdir ~/.omp
mkdir -p ~/.local/bin
ln -sf "$SCRIPT_DIR/run.sh" ~/.local/bin/omp
ln -sf "$SCRIPT_DIR/build.sh" ~/.local/bin/omp-build

echo "[install.sh] Installed: ~/.local/bin/omp, ~/.local/bin/omp-build"
