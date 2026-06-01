# Repository Guidelines

For install, configuration, CLI usage, and architecture overview, see [README.md](README.md).

## Code Conventions & Common Patterns

- `entrypoint.sh` uses `set -uo pipefail` (no errexit, since it dispatches). Both code paths use `exec` for clean signal handling (PID 1 handoff).
- The Makefile resolves its own directory via `$(dir $(realpath $(lastword $(MAKEFILE_LIST))))` and loads env via `-include .env.default.properties` (with optional `.env.properties` for local overrides).
- Config variables (`WORKSPACE_DIR`, `OMP_STATE_DIR`, `SSH_DIR`, etc.) are explicitly `export`ed so `docker compose` receives actual values, not just Make-internal variables.
- `make docker.update` busts the Docker build cache by passing `--build-arg update-token=$(date +%s)`, which invalidates the `RUN omp update` step in the Dockerfile.
- `compose.yaml` uses variable expansion with defaults: `${WORKSPACE_DIR:-.}`, `${OMP_STATE_DIR:-$HOME/.omp}`, and `${SSH_DIR:-$HOME/.ssh}`.
- Named volumes (`pip-cache`, `npm-cache`) persist package caches across container runs.

## Testing & QA

- No formal test suite exists in this repository.
- Validation is manual: run `make install`, then verify `omp-docker` launches and mounts the working directory correctly.
- Container health can be checked by running `make docker.run echo "ok"`.
- CI runs `make docker.build` and `make docker.run echo "ok"` via GitHub Actions.

## Important Notes

- `~/.omp` is mounted read-write into the container for persistent agent state across runs.
- `~/.gitconfig` is mounted read-only into the container for git identity (user.name/email). The Makefile auto-detects its presence — when missing, `/dev/null` is mounted instead to avoid Docker creating a directory. Git signing is configured separately via `GIT_CONFIG_COUNT` environment variables.
- `~/.ssh` is mounted read-only into the container for SSH commit signing. The entrypoint copies it to `/tmp/.ssh` and sets permissions to 600 (SSH rejects configs with world-readable perms). `GIT_CONFIG_COUNT=4` configures `safe.directory`, `gpg.format=ssh`, `user.signingkey`, and `commit.gpgsign=true`.
- Resource limits are enforced via `deploy.resources.limits` (CPU and memory).
- Cache persistence uses named volumes (`pip-cache`, `npm-cache`).

## Runtime & Tooling

- **Runtime**: Bun (base image `oven/bun:1.3`)
- **Package manager**: Bun (globally installed CLIs via `bun install -g`)
- **Python**: venv at `/opt/omp-venv` inside container (with ipykernel)
- **Rust**: Only used transiently during image build for `@anush008/tokenizers` napi addon; uninstalled after build
- **Working directory**: `/work` inside container (mapped to host `$PWD`)
