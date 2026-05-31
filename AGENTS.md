# Repository Guidelines

## Project Overview

**Oh My Pi (OMP)** is a Docker-based coding agent harness. It packages a rich development environment (Bun, Python, Rust toolchain for napi builds, ripgrep, fd-find, build-essential) inside a container image built on `oven/bun`. Host-side CLI commands (`omp-docker`, `omp-docker-build`, `omp-docker-update`) delegate into the container, mounting the current working directory as `/work` so the agent operates on your local files.

## Architecture & Data Flow

```
Host                         Container
────                         ─────────
omp-docker [args]
  └─ make docker.run
      └─ docker compose run --rm omp
          └─ entrypoint.sh
              ├─ omp update
              └─ exec omp [args] or direct command
```

1. **Host CLI**: `omp-docker` or `omp-docker-build` (symlinked via `make install`) calls `make docker.run` or `make docker.build`.
2. **compose.yaml**: mounts `$PWD → /work`, `~/.omp → /root/.omp` (persistent state). Grants `NET_ADMIN` + `NET_RAW` capabilities for network-level tasks. Resource limits enforced via `deploy.resources.limits`.
3. **entrypoint.sh**: runs `omp update` on boot, then dispatches — execs the command directly if it's in the allowlist (omp, bash, sh), otherwise delegates to `omp $@`.
4. **Container image** (Dockerfile): layers system packages → Python venv (`/opt/omp-venv` with ipykernel) → Bun agent packages → transient Rust for napi tokenizer build → cleanup.

## Key Directories & Files

|Path|Purpose|
|---|---|
|`Makefile`|Primary CLI interface for all docker operations|
|`Dockerfile`|Container image definition. Base: `oven/bun:1.2`. Installs dev tools, Python venv, Bun agent packages, and compiles napi tokenizers.|
|`compose.yaml`|Docker Compose service definition. Mounts, env vars, capabilities, resource limits, network isolation.|
|`entrypoint.sh`|Container entry point. Runs `omp update`, dispatches commands with allowlist.|
|`.env.default.properties`|Committed default configuration|
|`.env.properties`|Local overrides (gitignored)|

## Development Commands

```bash
# First-time setup
make install                    # Builds image + installs CLI symlinks

# Run the agent in current directory
make docker.run [args]          # or: omp-docker [args] after install

# Rebuild the container image
make docker.build               # or: omp-docker-build after install

# Direct docker compose usage
make docker.run                 # Interactive agent shell
make docker.build               # Rebuild image only
make help                       # Show all available commands
```

## Runtime & Tooling Preferences

- **Runtime**: Bun (base image `oven/bun:1.2`)
- **Package manager**: Bun (globally installed CLIs via `bun install -g`)
- **Container**: Docker Compose required on host
- **Python**: venv at `/opt/omp-venv` inside container (with ipykernel)
- **Rust**: Only used transiently during image build for `@anush008/tokenizers` napi addon; uninstalled after build
- **Working directory**: `/work` inside container (mapped to host `$PWD`)

## Code Conventions & Common Patterns

- Host-side scripts use `set -euo pipefail` (strict mode). `entrypoint.sh` uses `set -uo pipefail` (no errexit, since it dispatches).
- The Makefile resolves its own directory via `$(dir $(realpath $(lastword $(MAKEFILE_LIST))))`.
- `make docker.run` runs the container; `make docker.build` builds the image; `make docker.update` rebuilds with cache busting.
- The entrypoint uses `exec` for clean signal handling (PID 1 handoff).
- `compose.yaml` uses variable expansion with defaults: `${WORKSPACE_DIR:-.}`.
- Environment variables are loaded from `.env.default.properties` then `.env.properties`.

## Testing & QA

- No formal test suite exists in this repository.
- Validation is manual: run `make install`, then verify `omp-docker` launches and mounts the working directory correctly.
- Container health can be checked by running `make docker.run echo "ok"`.

## Important Notes

- `~/.omp` is mounted read-write into the container for persistent agent state across runs.
- Git identity is passed via environment variables (no `~/.gitconfig` mount) for security.
- `GIT_CONFIG_COUNT=1` and `safe.directory=/work` are configured to avoid git ownership warnings.
- Resource limits are enforced via `deploy.resources.limits` (CPU and memory).
- Cache persistence uses named volumes (`pip-cache`, `npm-cache`).
