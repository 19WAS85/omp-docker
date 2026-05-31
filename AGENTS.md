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
              └─ exec omp [args] or direct command
```

1. **Host CLI**: `omp-docker` or `omp-docker-build` (wrapper scripts created via `make install`) calls `make docker.run` or `make docker.build`.
2. **compose.yaml**: mounts `$PWD → /work`, `~/.omp → /root/.omp` (persistent state). Grants `NET_ADMIN` + `NET_RAW` capabilities for network-level tasks. Resource limits enforced via `deploy.resources.limits`. Named volumes persist pip and npm caches.
3. **entrypoint.sh**: dispatches commands — execs the command directly if it's in the known list (omp, bash, sh), otherwise delegates to `omp $@`. Includes signal trapping for clean shutdown.
4. **Container image** (Dockerfile): layers system packages → Python venv (`/opt/omp-venv` with ipykernel) → Bun agent packages → transient Rust for napi tokenizer build → `omp update` at build time → cleanup. HEALTHCHECK runs `omp --version`.

## Key Directories & Files

|Path|Purpose|
|---|---|
|`Makefile`|Primary CLI interface for all docker operations|
|`Dockerfile`|Container image definition. Base: `oven/bun:1.2`. Installs dev tools, Python venv, Bun agent packages, and compiles napi tokenizers.|
|`compose.yaml`|Docker Compose service definition. Mounts, env vars, capabilities, resource limits, network isolation.|
|`entrypoint.sh`|Container entry point. Dispatches commands via allowlist, traps signals for clean shutdown.|
|`.env.default.properties`|Committed default configuration|
|`.env.properties`|Local overrides (gitignored)|
|`.dockerignore`|Excludes .git, docs, scripts, markdown, env files, and compose.d from build context|

## Development Commands

```bash
# First-time setup
make install                    # Builds image + installs CLI wrapper scripts

# Run the agent in current directory
make docker.run [args]          # or: omp-docker [args] after install

# Rebuild the container image
make docker.build               # or: omp-docker-build after install

# Rebuild with fresh OMP packages (cache-busting via build arg)
make docker.update              # or: omp-docker-update after install

# Teardown
make uninstall                  # Removes CLI wrapper scripts
make docker.stop                # Stops running containers
make docker.clean               # Removes all project images

# Other targets
make docker                     # Build + run interactively
make docker.run.d               # Run detached
make docker.ls                  # List project images
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

- `entrypoint.sh` uses `set -uo pipefail` (no errexit, since it dispatches) and traps `SIGTERM`/`SIGINT` for clean shutdown.
- The Makefile resolves its own directory via `$(dir $(realpath $(lastword $(MAKEFILE_LIST))))` and loads env via `-include .env.default.properties` / `.env.properties`.
- `make docker.update` busts the Docker build cache by passing `--build-arg update-token=$(date +%s)`, which invalidates the `RUN omp update` step in the Dockerfile.
- The entrypoint uses `exec` for clean signal handling (PID 1 handoff).
- `compose.yaml` uses variable expansion with defaults: `${WORKSPACE_DIR:-.}` and `${OMP_STATE_DIR:-~/.omp}`.
- Named volumes (`pip-cache`, `npm-cache`) persist package caches across container runs.

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
