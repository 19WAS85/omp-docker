# Repository Guidelines

## Project Overview

**Oh My Pi (OMP)** is a Docker-based coding agent harness. It packages a rich development environment (Bun, Python, Rust toolchain for napi builds, ripgrep, fd-find, build-essential) inside a container image built on `oven/bun`. Host-side CLI commands (`omp`, `omp-build`) delegate into the container, mounting the current working directory as `/work` so the agent operates on your local files.

## Architecture & Data Flow

```
Host                         Container
────                         ─────────
omp [args]                  
  └─ run.sh / build.sh     
      └─ docker compose run 
          └─ entrypoint.sh  
              ├─ omp update  
              └─ exec omp [args] or direct command
```

1. **Host CLI**: `omp` or `omp-build` (symlinked via `install.sh`) calls `docker compose run --rm omp "$@"`.
2. **compose.yaml**: mounts `$PWD → /work`, `~/.omp → /root/.omp` (persistent state), `~/.gitconfig → /root/.gitconfig` (read-only). Grants `NET_ADMIN` + `NET_RAW` capabilities for network-level tasks.
3. **entrypoint.sh**: runs `omp update` on boot, then dispatches — execs the command directly if it's a known binary, otherwise delegates to `omp $@`.
4. **Container image** (Dockerfile): layers system packages → Python venv (`/opt/omp-venv` with ipykernel) → Bun global CLIs (`@oh-my-pi/pi-coding-agent`, `@oh-my-pi/pi-natives`) → transient Rust for napi tokenizer build → cleanup.

## Key Directories & Files

| Path | Purpose |
|---|---|
| `Dockerfile` | Container image definition. Base: `oven/bun`. Installs dev tools, Python venv, Bun agent packages, and compiles napi tokenizers. |
| `compose.yaml` | Docker Compose service definition. Mounts, env vars, capabilities. |
| `entrypoint.sh` | Container entry point. Runs `omp update`, dispatches commands. |
| `run.sh` | Host CLI wrapper — `docker compose run --rm omp "$@"`. |
| `build.sh` | Duplicate of `run.sh`. Symlinked as `omp-build`. |
| `install.sh` | One-time setup: builds image, symlinks `omp`/`omp-build` into `~/.local/bin`. |

## Development Commands

```bash
# First-time setup
./install.sh                    # Builds image + installs CLI symlinks

# Run the agent in current directory
./run.sh [args]                 # or: omp [args] after install

# Rebuild the container image
./build.sh                      # or: omp-build after install

# Direct docker compose usage
docker compose run --rm omp     # Interactive agent shell
docker compose build            # Rebuild image only
```

## Runtime & Tooling Preferences

- **Runtime**: Bun (base image `oven/bun`)
- **Package manager**: Bun (globally installed CLIs via `bun install -g`)
- **Container**: Docker Compose required on host
- **Python**: venv at `/opt/omp-venv` inside container (with ipykernel)
- **Rust**: Only used transiently during image build for `@anush008/tokenizers` napi addon; uninstalled after build
- **Working directory**: `/work` inside container (mapped to host `$PWD`)

## Code Conventions & Common Patterns

- All shell scripts use `set -euo pipefail` (strict mode).
- Scripts resolve their own directory via `SCRIPT_DIR` pattern.
- `run.sh` and `build.sh` are identical — both forward arguments to `docker compose run`.
- The entrypoint uses `exec` for clean signal handling (PID 1 handoff).
- `compose.yaml` uses variable expansion with defaults: `${OMP_WORKDIR:-.}`.

## Testing & QA

- No formal test suite exists in this repository.
- Validation is manual: run `./install.sh`, then verify `omp` launches and mounts the working directory correctly.
- Container health can be checked by running `docker compose run --rm omp echo "ok"`.

## Important Notes

- `~/.omp` is mounted read-write into the container for persistent agent state across runs.
- `~/.gitconfig` is mounted read-only for git identity without modifying host config.
- `GIT_CONFIG_COUNT=1` and `GIT_CONFIG_GLOBAL=/root/.gitconfig` are set in compose.yaml; `safe.directory=/work` is configured to avoid git ownership warnings.
- `run.sh` and `build.sh` are functionally identical — the `omp-build` symlink exists as a convenience alias.
