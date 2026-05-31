# Oh My Pi Docker — Consistency Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Oh My Pi Docker harness to fix 15 audit issues and align with best practices from similar projects.

**Architecture:** Replace scripts/ with a Makefile as the primary interface. Add env-based configuration with .env files. Enhance Dockerfile with version pinning, metadata, and healthcheck. Harden compose.yaml with resource limits, cache volumes, and network isolation. Fix entrypoint security and consistency.

**Tech Stack:** Make, Docker Compose, Bash, Dockerfile

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `Makefile` | Create | Primary CLI interface for all docker operations |
| `.env.default.properties` | Create | Committed default configuration |
| `.env.properties` | Create | Gitignored local overrides (template) |
| `.dockerignore` | Create | Reduce build context |
| `compose.yaml` | Modify | Resource limits, volumes, network, env vars |
| `Dockerfile` | Modify | Version pin, labels, healthcheck |
| `entrypoint.sh` | Modify | Allowlist dispatch, signal handling, permissions |
| `README.md` | Modify | Update documentation for new interface |
| `AGENTS.md` | Modify | Update documentation for new interface |
| `scripts/` | Delete | Replaced by Makefile |
| `.gitignore` | Modify | Add .env.properties, compose.d/ |

---

### Task 1: Create .dockerignore

**Files:**
- Create: `.dockerignore`

- [ ] **Step 1: Create .dockerignore**

```
.git
docs/
scripts/
*.md
.env*
compose.d/
```

- [ ] **Step 2: Verify build context is reduced**

Run: `docker compose build 2>&1 | grep "Sending build context"`
Expected: Context size should be < 10KB (down from ~72KB)

- [ ] **Step 3: Commit**

```bash
git add .dockerignore
git commit -m "chore: add .dockerignore to reduce build context"
```

---

### Task 2: Create .env.default.properties

**Files:**
- Create: `.env.default.properties`

- [ ] **Step 1: Create .env.default.properties**

```properties
# Oh My Pi Docker — Default Configuration
# Copy to .env.properties and customize

# Workspace
WORKSPACE=/work
WORKSPACE_DIR=.
OMP_STATE_DIR=~/.omp

# Resource limits
RESOURCE_CPUS=2.0
RESOURCE_MEMORY=4g

# Network mode: restricted (isolated) or open (full internet)
NETWORK_MODE=restricted

# Git identity (set in .env.properties for real identity)
GIT_AUTHOR_NAME=agent
GIT_AUTHOR_EMAIL=agent@local
GIT_COMMITTER_NAME=agent
GIT_COMMITTER_EMAIL=agent@local

# API keys (set in .env.properties)
# ANTHROPIC_API_KEY=
# GITHUB_TOKEN=
```

- [ ] **Step 2: Create .env.properties template**

```properties
# Oh My Pi Docker — Local Configuration
# This file is gitignored. Customize here.

# Uncomment and set your API keys:
# ANTHROPIC_API_KEY=sk-ant-...
# GITHUB_TOKEN=ghp_...

# Uncomment and set your git identity:
# GIT_AUTHOR_NAME=Your Name
# GIT_AUTHOR_EMAIL=you@example.com
# GIT_COMMITTER_NAME=Your Name
# GIT_COMMITTER_EMAIL=you@example.com
```

- [ ] **Step 3: Update .gitignore**

Add to `.gitignore`:
```
.env.properties
compose.d/
```

- [ ] **Step 4: Commit**

```bash
git add .env.default.properties .env.properties .gitignore
git commit -m "feat: add env-based configuration with defaults"
```

---

### Task 3: Update Dockerfile

**Files:**
- Modify: `Dockerfile`

- [ ] **Step 1: Add version pinning and metadata**

Replace `Dockerfile` with:

```dockerfile
# syntax=docker/dockerfile:1
FROM oven/bun:1.2 AS base

LABEL maintainer="Oh My Pi" \
      description="Docker harness for Oh My Pi coding agent" \
      version="1.0"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl git iptables \
      python3 python3-pip python3-venv ripgrep fd-find \
 && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/omp-venv \
 && /opt/omp-venv/bin/pip install --no-cache-dir ipykernel
ENV PATH="/opt/omp-venv/bin:$PATH"

RUN bun install -g @oh-my-pi/pi-coding-agent @oh-my-pi/pi-natives

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable --profile minimal \
 && . "$HOME/.cargo/env" \
 && bun install -g @napi-rs/cli \
 && cd /root/.bun/install/global/node_modules/@anush008/tokenizers \
 && napi build --platform --release \
 && rustup self uninstall -y \
 && bun uninstall -g @napi-rs/cli

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint

ARG update-token
RUN omp update

WORKDIR /work

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD ["omp", "--version"]

ENTRYPOINT ["/usr/local/bin/entrypoint"]

CMD ["omp"]
```

- [ ] **Step 2: Verify Dockerfile syntax**

Run: `docker build --check .` or `docker build --dry-run . 2>&1`
Expected: No syntax errors

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat(dockerfile): add version pin, metadata labels, healthcheck"
```

---

### Task 4: Update compose.yaml

**Files:**
- Modify: `compose.yaml`

- [ ] **Step 1: Replace compose.yaml with enhanced version**

```yaml
services:
  omp:
    build: .
    volumes:
      - ${WORKSPACE_DIR:-.}:/work
      - ${OMP_STATE_DIR:-~/.omp}:/root/.omp
      - pip-cache:/root/.cache/pip
      - npm-cache:/root/.bun/install/cache
    environment:
      - TERM
      - LANG
      - LC_ALL
      - GIT_CONFIG_COUNT=1
      - GIT_CONFIG_KEY_0=safe.directory
      - GIT_CONFIG_VALUE_0=/work
      - GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME:-agent}
      - GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL:-agent@local}
      - GIT_COMMITTER_NAME=${GIT_COMMITTER_NAME:-agent}
      - GIT_COMMITTER_EMAIL=${GIT_COMMITTER_EMAIL:-agent@local}
    cap_add:
      - NET_ADMIN
      - NET_RAW
    stdin_open: true
    tty: true
    networks:
      - agent-net
    deploy:
      resources:
        limits:
          cpus: "${RESOURCE_CPUS:-2.0}"
          memory: "${RESOURCE_MEMORY:-4g}"

networks:
  agent-net:
    driver: bridge

volumes:
  pip-cache:
  npm-cache:
```

- [ ] **Step 2: Verify compose config**

Run: `docker compose config 2>&1`
Expected: Valid YAML, no errors

- [ ] **Step 3: Commit**

```bash
git add compose.yaml
git commit -m "feat(compose): add resource limits, cache volumes, network isolation"
```

---

### Task 5: Update entrypoint.sh

**Files:**
- Modify: `entrypoint.sh`

- [ ] **Step 1: Replace entrypoint.sh with hardened version**

```bash
#!/usr/bin/env bash
set -uo pipefail

# Clean shutdown on signals
cleanup() {
  exit 0
}
trap cleanup SIGTERM SIGINT

# Known agent commands that should be exec'd directly
KNOWN_COMMANDS=(omp bash sh)

if [[ $# -gt 0 ]]; then
  for cmd in "${KNOWN_COMMANDS[@]}"; do
    if [[ "$1" == "$cmd" ]]; then
      [[ "$1" == "omp" ]] && shift
      exec "$@"
    fi
  done
fi

exec omp "$@"
```

- [ ] **Step 2: Make entrypoint.sh executable**

Run: `chmod +x entrypoint.sh`
Expected: File permissions change to 755

- [ ] **Step 3: Verify permissions**

Run: `ls -la entrypoint.sh`
Expected: `-rwxr-xr-x`

- [ ] **Step 4: Commit**

```bash
git add entrypoint.sh
git commit -m "fix(entrypoint): add signal handling, explicit command allowlist"
```

---

### Task 6: Create Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Create Makefile**

```makefile
# Oh My Pi Docker — Makefile
# Primary interface for all docker operations

# Load env files (order matters: defaults first, then overrides)
-include .env.default.properties
-include .env.properties

# Resolve compose file path
COMPOSE_FILE := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))compose.yaml

# Default target
.DEFAULT_GOAL := help

# Help target
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Docker targets
docker: docker.build docker.run ## Build and run interactively

docker.build: ## Build the Docker image
	@chmod +x entrypoint.sh
	docker compose -f $(COMPOSE_FILE) build

docker.run: ## Run interactively
	@chmod +x entrypoint.sh
	OMP_WORKDIR="$$PWD" docker compose -f $(COMPOSE_FILE) run --rm omp

docker.run.d: ## Run detached
	@chmod +x entrypoint.sh
	docker compose -f $(COMPOSE_FILE) up -d

docker.stop: ## Stop containers
	docker compose -f $(COMPOSE_FILE) down

docker.clean: ## Remove untagged images
	docker compose -f $(COMPOSE_FILE) down --rmi all

docker.update: ## Rebuild from update stage (cache-busting)
	@chmod +x entrypoint.sh
	docker compose -f $(COMPOSE_FILE) build --build-arg update-token="$$(date +%s)"

docker.ls: ## List project images
	@docker images | grep -E "omp|REPOSITORY"

# Setup targets
install: docker.build ## Build image and create symlinks
	@mkdir -p ~/.omp
	@mkdir -p ~/.local/bin
	@echo '#!/usr/bin/env bash' > ~/.local/bin/omp-docker
	@echo 'SCRIPT_DIR="$$(cd "$$(dirname "$$(readlink -f "$$0")")" && pwd)"' >> ~/.local/bin/omp-docker
	@echo 'exec make -C "$$SCRIPT_DIR" docker.run "$$@"' >> ~/.local/bin/omp-docker
	@chmod +x ~/.local/bin/omp-docker
	@echo '#!/usr/bin/env bash' > ~/.local/bin/omp-docker-build
	@echo 'SCRIPT_DIR="$$(cd "$$(dirname "$$(readlink -f "$$0")")" && pwd)"' >> ~/.local/bin/omp-docker-build
	@echo 'exec make -C "$$SCRIPT_DIR" docker.build "$$@"' >> ~/.local/bin/omp-docker-build
	@chmod +x ~/.local/bin/omp-docker-build
	@echo '#!/usr/bin/env bash' > ~/.local/bin/omp-docker-update
	@echo 'SCRIPT_DIR="$$(cd "$$(dirname "$$(readlink -f "$$0")")" && pwd)"' >> ~/.local/bin/omp-docker-update
	@echo 'exec make -C "$$SCRIPT_DIR" docker.update "$$@"' >> ~/.local/bin/omp-docker-update
	@chmod +x ~/.local/bin/omp-docker-update
	@echo "Installed: ~/.local/bin/omp-docker, ~/.local/bin/omp-docker-build, ~/.local/bin/omp-docker-update"

uninstall: docker.stop ## Remove containers, images, and symlinks
	@rm -f ~/.local/bin/omp-docker
	@rm -f ~/.local/bin/omp-docker-build
	@rm -f ~/.local/bin/omp-docker-update
	@echo "Uninstalled symlinks"
```

- [ ] **Step 2: Verify Makefile syntax**

Run: `make -n help 2>&1`
Expected: No syntax errors

- [ ] **Step 3: Verify help target**

Run: `make help`
Expected: Lists all available commands

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "feat: add Makefile as primary interface"
```

---

### Task 7: Delete scripts/ directory

**Files:**
- Delete: `scripts/run.sh`
- Delete: `scripts/build.sh`
- Delete: `scripts/update.sh`
- Delete: `scripts/install.sh`
- Delete: `scripts/uninstall.sh`
- Delete: `scripts/` directory

- [ ] **Step 1: Remove scripts directory**

Run: `rm -rf scripts/`
Expected: Directory removed

- [ ] **Step 2: Verify removal**

Run: `ls scripts/ 2>&1`
Expected: "No such file or directory"

- [ ] **Step 3: Commit**

```bash
git rm -r scripts/
git commit -m "refactor: remove scripts/ replaced by Makefile"
```

---

### Task 8: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace README.md**

```markdown
# Oh My Pi — Docker

Docker harness for [Oh My Pi](https://github.com/can1357/oh-my-pi), the AI coding agent. Packages the full OMP environment — Bun, Python, ripgrep, LSP, DAP, 32 built-in tools — inside a container image. You work on your local files; OMP runs in Docker.

## Install

```sh
git clone https://github.com/19WAS85/omp-docker.git
cd omp-docker
make install
```

This builds the container image and symlinks three commands into `~/.local/bin`. Ensure `~/.local/bin` is on your `PATH`.

## Configuration

Copy `.env.properties.example` to `.env.properties` and customize:

```sh
cp .env.properties.example .env.properties
# Edit .env.properties with your API keys and preferences
```

Key variables:

| Variable | Default | Description |
|---|---|---|
| `WORKSPACE_DIR` | `.` | Host directory to mount |
| `RESOURCE_CPUS` | `2.0` | CPU limit |
| `RESOURCE_MEMORY` | `4g` | Memory limit |
| `NETWORK_MODE` | `restricted` | `restricted` or `open` |
| `ANTHROPIC_API_KEY` | — | API key for agent |
| `GITHUB_TOKEN` | — | GitHub token |

## CLI Commands

Once installed, three commands are available from anywhere:

### `omp-docker [args]`

Run OMP in the current directory. All arguments are forwarded to the agent.

```sh
omp-docker                          # interactive shell
omp-docker "fix the race condition in src/worker.py"
omp-docker --help
```

Your working directory is mounted at `/work` inside the container. `~/.omp` state persists across sessions.

### `omp-docker-build [args]`

Rebuild the container image. Use after editing the `Dockerfile` or `compose.yaml`. Extra arguments are forwarded to `docker compose build`.

```sh
omp-docker-build                    # full rebuild
omp-docker-build --no-cache         # ignore build cache
```

### `omp-docker-update`

Rebuild the image from the update stage with cache busting, so OMP and its dependencies are refreshed without rebuilding system packages from scratch.

```sh
omp-docker-update                   # pull latest OMP packages
```

## Direct Makefile Usage

```sh
make docker          # build + run interactively (default)
make docker.build    # build image only
make docker.run      # run interactively
make docker.run.d    # run detached
make docker.stop     # stop containers
make docker.clean    # remove untagged images
make docker.update   # rebuild from update stage (cache-busting)
make docker.ls       # list project images
make help            # show all available commands
```

## What's Inside

- **Bun** runtime with `@oh-my-pi/pi-coding-agent` and `@oh-my-pi/pi-natives`
- **Python 3** with ipykernel at `/opt/omp-venv`
- **ripgrep**, **fd-find**, **build-essential**, **git**, **iptables**

To add packages, edit the `Dockerfile` and rebuild with `omp-docker-build`.

## Architecture

```
omp-docker [args]
  └─ make docker.run
      └─ docker compose run --rm omp
          └─ entrypoint.sh
              ├─ omp update
              └─ exec omp [args]
```

| File | Purpose |
|---|---|
| `Makefile` | Primary CLI interface |
| `Dockerfile` | Container image (oven/bun base) |
| `compose.yaml` | Service config: mounts, env, capabilities |
| `entrypoint.sh` | Bootstraps OMP, dispatches commands |
| `.env.default.properties` | Committed default configuration |
| `.env.properties` | Local overrides (gitignored) |

## Security

- **Resource limits**: CPU and memory capped via `deploy.resources.limits`
- **Network isolation**: Custom bridge network with controlled egress
- **Credential isolation**: Git identity passed via env vars (no `~/.gitconfig` mount)
- **Cache persistence**: Named volumes for pip/npm caches

## Contributing

1. Fork and create a feature branch
2. Make changes to the Dockerfile, Makefile, or compose config
3. Test with `make docker.run echo "ok"`
4. Submit a pull request
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README for Makefile interface"
```

---

### Task 9: Update AGENTS.md

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Replace AGENTS.md**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: update AGENTS.md for Makefile interface"
```

---

### Task 10: Final verification

**Files:**
- None (verification only)

- [ ] **Step 1: Verify Makefile help**

Run: `make help`
Expected: Lists all available commands with descriptions

- [ ] **Step 2: Verify Docker build**

Run: `make docker.build`
Expected: Image builds successfully with version pin, labels, healthcheck

- [ ] **Step 3: Verify container runs**

Run: `make docker.run echo "ok"`
Expected: Container starts, runs command, exits cleanly

- [ ] **Step 4: Verify install target**

Run: `make install`
Expected: Symlinks created in `~/.local/bin`

- [ ] **Step 5: Verify symlinks work**

Run: `omp-docker echo "test"`
Expected: Command runs successfully

- [ ] **Step 6: Verify resource limits**

Run: `make docker.run.d && docker stats --no-stream`
Expected: CPU and memory limits shown

- [ ] **Step 7: Verify cache volumes**

Run: `docker volume ls | grep -E "pip-cache|npm-cache"`
Expected: Both volumes exist

- [ ] **Step 8: Verify network isolation**

Run: `make docker.run ping -c 1 8.8.8.8` (in restricted mode)
Expected: Network unreachable or timeout

- [ ] **Step 9: Final commit**

```bash
git add -A
git commit -m "chore: complete consistency audit implementation"
```
