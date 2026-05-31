# Oh My Pi — Docker

Docker harness for [Oh My Pi](https://github.com/can1357/oh-my-pi), the AI coding agent. Packages the full OMP environment — Bun, Python, ripgrep, LSP, DAP, 32 built-in tools — inside a container image. You work on your local files; OMP runs in Docker.

## Install

```sh
git clone https://github.com/19WAS85/omp-docker.git
cd omp-docker
./scripts/install.sh
```

This builds the container image and symlinks three commands into `~/.local/bin`. Ensure `~/.local/bin` is on your `PATH`.

## CLI Commands

Once installed, three commands are available from anywhere:

### `omp-docker [args]`

Run OMP in the current directory. All arguments are forwarded to the agent.

```sh
omp-docker                          # interactive shell
omp-docker "fix the race condition in src/worker.py"
omp-docker --help
```

Your working directory is mounted at `/work` inside the container. `~/.omp` state persists across sessions. Git identity is read from your host `~/.gitconfig`.

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

## What's Inside

- **Bun** runtime with `@oh-my-pi/pi-coding-agent` and `@oh-my-pi/pi-natives`
- **Python 3** with ipykernel at `/opt/omp-venv`
- **ripgrep**, **fd-find**, **build-essential**, **git**, **iptables**

To add packages, edit the `Dockerfile` and rebuild with `omp-docker-build`.

## Architecture

```
omp-docker [args]
  └─ docker compose run --rm omp
      └─ entrypoint.sh
          ├─ omp update
          └─ exec omp [args]
```

| File | Purpose |
|---|---|
| `Dockerfile` | Container image (oven/bun base) |
| `compose.yaml` | Service config: mounts, env, capabilities |
| `entrypoint.sh` | Bootstraps OMP, dispatches commands |
| `scripts/run.sh` | `omp-docker` implementation |
| `scripts/build.sh` | `omp-docker-build` implementation |
| `scripts/update.sh` | `omp-docker-update` implementation |
| `scripts/install.sh` | One-time setup: builds image + creates symlinks |
| `scripts/uninstall.sh` | Removes containers, images, and symlinks |

## Contributing

1. Fork and create a feature branch
2. Make changes to the Dockerfile, scripts, or compose config
3. Test with `omp-docker echo "ok"`
4. Submit a pull request
