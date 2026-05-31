# Oh My Pi — Docker

Docker harness for [Oh My Pi](https://github.com/can1357/oh-my-pi), the AI coding agent. Packages the full OMP environment — Bun, Python, ripgrep, LSP, DAP, 32 built-in tools — inside a container image. You work on your local files; OMP runs in Docker.

## Prerequisites

- Docker with Compose v2
- `~/.gitconfig` on the host (created automatically if missing)

## Install

```sh
git clone https://github.com/<owner>/oh-my-pi-docker.git
cd oh-my-pi-docker
./install.sh
```

This builds the container image and symlinks `omp` and `omp-build` into `~/.local/bin`. Ensure `~/.local/bin` is on your `PATH`.

## Usage

```sh
# Run OMP in the current directory
omp [args]

# Rebuild the container image after Dockerfile changes
omp-build
```

OMP mounts your working directory as `/work` inside the container. Your `~/.omp` state persists across sessions. Git identity is read from your host `~/.gitconfig`.

### Docker Compose

```sh
# Direct usage without the CLI wrappers
docker compose run --rm omp

# Rebuild image only
docker compose build
```

## Customization

The container environment is configured in `compose.yaml`. Key options:

| Variable | Default | Purpose |
|---|---|---|
| `OMP_WORKDIR` | `.` (current dir) | Host directory mounted as `/work` |

The container image includes:

- **Bun** runtime with `@oh-my-pi/pi-coding-agent` and `@oh-my-pi/pi-natives`
- **Python 3** with ipykernel at `/opt/omp-venv`
- **ripgrep**, **fd-find**, **build-essential**, **git**, **iptables**

To add packages, edit the `Dockerfile` and rebuild with `omp-build`.

## Architecture

```
Host                          Container
────                          ─────────
omp [args]
  └─ run.sh / build.sh
      └─ docker compose run
          └─ entrypoint.sh
              ├─ omp update
              └─ exec omp [args]
```

| File | Purpose |
|---|---|
| `Dockerfile` | Container image definition (oven/bun base) |
| `compose.yaml` | Service config: mounts, env, capabilities |
| `entrypoint.sh` | Bootstraps OMP, dispatches commands |
| `run.sh` / `build.sh` | Host CLI wrappers |
| `install.sh` | One-time setup: build + symlinks |

## Contributing

1. Fork and create a feature branch
2. Make changes to the Dockerfile, scripts, or compose config
3. Test with `./install.sh` then `omp echo "ok"`
4. Submit a pull request
