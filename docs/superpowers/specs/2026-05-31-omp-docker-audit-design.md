# Oh My Pi Docker — Consistency Audit & Best Practices Redesign

**Date:** 2026-05-31
**Status:** Approved
**Scope:** All 15 audit issues across security, Docker best practices, consistency, and robustness

## Overview

This spec redesigns the Oh My Pi Docker harness to align with best practices from similar projects (claude-code-docker, harness-hat, agent-sandbox patterns) and fix 15 consistency/security issues found during audit.

## Audit Findings (15 Issues)

### Security (3)
1. `~/.gitconfig` mounted read-only — exposes credential helpers, proxy settings
2. No resource limits — runaway agent loops consume unbounded host resources
3. No network isolation — default bridge allows unrestricted outbound

### Docker Best Practices (5)
4. No `.dockerignore` — `.git/`, `docs/`, `scripts/` sent in build context
5. Base image `oven/bun` not version-pinned
6. No `LABEL` metadata
7. No `HEALTHCHECK`
8. Multi-stage build could reduce image size

### Consistency (3)
9. `entrypoint.sh` has `644` permissions (not executable)
10. Compose file reference inconsistent across scripts
11. `entrypoint.sh` uses `set -uo pipefail` (no `-e`), scripts use `set -euo pipefail`

### Robustness (4)
12. `entrypoint.sh` dispatch is fragile — `command -v "$1"` matches any binary
13. No `.env` or `.env.example` for configuration
14. No named volumes for pip/npm caches
15. No CI/CD or automated validation

---

## Design: Makefile + Configuration

### Makefile as primary interface

Replace `scripts/` with a `Makefile`. Commands:

```makefile
# Primary commands
make docker          # Build + run interactively (default)
make docker.build    # Build image only
make docker.run      # Run interactively
make docker.run.d    # Run detached
make docker.stop     # Stop containers
make docker.clean    # Remove untagged images
make docker.update   # Rebuild from update stage (cache-busting)
make docker.ls       # List project images
make help            # Show all commands

# Setup
make install         # Build image + create symlinks
make uninstall       # Remove containers, images, symlinks
```

All commands forward env vars from `.env.properties`. The Makefile resolves its own directory and passes `-f compose.yaml` to docker compose.

### Env-based configuration

Two env files, loaded in order:

| File | Committed? | Purpose |
|---|---|---|
| `.env.default.properties` | Yes | Sensible defaults for all settings |
| `.env.properties` | No (gitignored) | Local overrides, secrets |

Key variables:

| Variable | Default | Description |
|---|---|---|
| `WORKSPACE` | `/work` | Container workspace path |
| `WORKSPACE_DIR` | `.` | Host directory to mount |
| `OMP_STATE_DIR` | `~/.omp` | Persistent agent state |
| `RESOURCE_CPUS` | `2.0` | CPU limit |
| `RESOURCE_MEMORY` | `4g` | Memory limit |
| `NETWORK_MODE` | `restricted` | `restricted` or `open` |
| `ANTHROPIC_API_KEY` | — | API key for agent |
| `GITHUB_TOKEN` | — | GitHub token |
### .env.default.properties contents

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

### Compose overlays

Drop `.yml` files into `compose.d/` to extend the base compose config. All files are automatically included. The directory is gitignored.

---

## Design: Dockerfile Improvements

### Version pinning

```dockerfile
FROM oven/bun:1.2 AS base
```

### Metadata labels

```dockerfile
LABEL maintainer="Oh My Pi" \
      description="Docker harness for Oh My Pi coding agent" \
      version="1.0"
```

### .dockerignore

```
.git
docs/
scripts/
*.md
.env*
compose.d/
```

Reduces build context from full repo to just `Dockerfile` and `entrypoint.sh`.

### HEALTHCHECK

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD ["omp", "--version"]
```

---

## Design: Compose.yaml Enhancements

### Resource limits

```yaml
deploy:
  resources:
    limits:
      cpus: "${RESOURCE_CPUS:-2.0}"
      memory: "${RESOURCE_MEMORY:-4g}"
```

### Named cache volumes

```yaml
volumes:
  - ${WORKSPACE_DIR:-.}:/work
  - ${OMP_STATE_DIR:-~/.omp}:/root/.omp
  - pip-cache:/root/.cache/pip
  - npm-cache:/root/.bun/install/cache

volumes:
  pip-cache:
  npm-cache:
```

### Network isolation

The `NETWORK_MODE` variable controls outbound access:

- `restricted` (default): Custom bridge network with no direct internet access. Agent routes through controlled egress.
- `open`: Default bridge network with full internet access.

Implementation in `compose.yaml`:

```yaml
networks:
  agent-net:
    driver: bridge

services:
  omp:
    networks:
      - agent-net
```

For `open` mode, the Makefile overrides by passing `--network host` or by using a separate compose overlay in `compose.d/`.

### Environment forwarding

```yaml
environment:
  - TERM
  - LANG
  - LC_ALL
  - GIT_CONFIG_COUNT=1
  - GIT_CONFIG_KEY_0=safe.directory
  - GIT_CONFIG_VALUE_0=/work
```

---

## Design: Security Hardening

### Credential isolation

Replace `~/.gitconfig` bind mount with explicit env vars:

```yaml
environment:
  - GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME:-agent}
  - GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL:-agent@local}
  - GIT_COMMITTER_NAME=${GIT_COMMITTER_NAME:-agent}
  - GIT_COMMITTER_EMAIL=${GIT_COMMITTER_EMAIL:-agent@local}
```

Users needing real git identity set these in `.env.properties`.

### Entrypoint improvements

Fix fragile dispatch with explicit allowlist:

```bash
#!/usr/bin/env bash
set -uo pipefail

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

### Signal handling

```bash
cleanup() {
  exit 0
}
trap cleanup SIGTERM SIGINT
```

---

## Design: Consistency Fixes

### File permissions

Ensure `entrypoint.sh` is executable. The Makefile's `docker.build` target handles this:

```makefile
docker.build:
	@chmod +x entrypoint.sh
	docker compose -f $(COMPOSE_FILE) build
```

### Script → Makefile migration

| Old Script | New Makefile Target |
|---|---|
| `scripts/run.sh` | `make docker.run` |
| `scripts/build.sh` | `make docker.build` |
| `scripts/update.sh` | `make docker.update` |
| `scripts/install.sh` | `make install` |
| `scripts/uninstall.sh` | `make uninstall` |

### Documentation updates

Update `README.md` and `AGENTS.md` to reflect:
- Makefile as primary interface
- New env-based configuration
- Updated security model (no gitconfig mount)
- Resource limits and cache volumes

### Install/uninstall improvements

The `install` target:
1. Builds the image
2. Creates `~/.omp` directory
3. Creates `~/.local/bin` if needed
4. Symlinks a wrapper script into `~/.local/bin`

Wrapper script (dynamically resolves Makefile location):

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
exec make -C "$SCRIPT_DIR" "$@"
```

---

## Files Modified

| File | Action |
|---|---|
| `Makefile` | Create — primary interface |
| `.env.default.properties` | Create — committed defaults |
| `.env.properties` | Create — gitignored local overrides |
| `.dockerignore` | Create — reduce build context |
| `Dockerfile` | Modify — version pin, labels, healthcheck |
| `compose.yaml` | Modify — resource limits, volumes, network, env |
| `entrypoint.sh` | Modify — allowlist dispatch, signal handling, permissions |
| `README.md` | Modify — update for Makefile interface |
| `AGENTS.md` | Modify — update for Makefile interface |
| `scripts/` | Delete — replaced by Makefile |

## Verification

1. `make docker.build` — image builds successfully
2. `make docker.run echo "ok"` — container runs and executes command
3. `make docker.update` — cache-busting rebuild works
4. `make install` — symlinks created in `~/.local/bin`
5. `make uninstall` — cleanup removes everything
6. `make help` — shows all available commands
7. Resource limits enforced: `docker stats` shows CPU/memory caps
8. Cache volumes persist: `docker volume ls` shows pip-cache and npm-cache
9. Network isolation: container cannot reach unrestricted internet in `restricted` mode
