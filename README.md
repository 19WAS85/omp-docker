# Oh My Pi

Dockerized coding agent environment for [Oh My Pi](https://github.com/nicholasgasior/oh-my-pi) (OMP).

> **Early-stage project** — APIs and workflows may change without notice.

## Install

```bash
./install.sh
```

This builds the Docker image and creates two symlinks in `~/.local/bin`:

| Symlink | Target |
|---------|--------|
| `~/.local/bin/omp` | `run.sh` |
| `~/.local/bin/omp-build` | `build.sh` |

Make sure `~/.local/bin` is in your `$PATH`.

## Usage

```bash
# Interactive agent session in the current directory
./run.sh

# Run a specific command inside the container
./run.sh python3 script.py
./run.sh bash

# Rebuild the image after Dockerfile changes
./build.sh
```

## How It Works

```
Host                    Container (oven/bun)
────                    ────────────────────
run.sh                  entrypoint.sh
  │                       ├─ git config
  │                       ├─ omp update
  │                       └─ exec omp
  ├─ $PWD ────────────► /work
  └─ ~/.omp ──────────► /root/.omp
```

The container mounts your working directory at `/work` and persists agent state in `~/.omp`. On startup the entrypoint configures git, updates the agent, then hands off to `omp`.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OMP_WORKDIR` | Host directory mounted as `/work` | `.` (set automatically by `run.sh`) |
| `GIT_USER_EMAIL` | Git email configured inside the container | *(not set)* |
| `GIT_USER_NAME` | Git username configured inside the container | *(not set)* |

## License

*Not yet determined.*
