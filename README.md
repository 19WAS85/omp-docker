# Oh My Pi — Docker

Docker harness for [Oh My Pi](https://github.com/can1357/oh-my-pi), the AI coding agent. Packages the full OMP environment — Bun, Python, ripgrep, LSP, DAP, 32 built-in tools — inside a container image. You work on your local files; OMP runs in Docker.

## Install

```sh
git clone https://github.com/19WAS85/omp-docker.git
cd omp-docker
make install
```

This builds the container image and creates wrapper scripts in `~/.local/bin`. Ensure `~/.local/bin` is on your `PATH`.

## Configuration

Edit `.env.default.properties` to customize settings, or set environment variables before running `make`. For secrets (API keys, tokens), create a local `.env.properties` file (gitignored).

| Variable | Default | Description |
|---|---|---|
| `WORKSPACE_DIR` | `.` | Host directory to mount at `/work` |
| `OMP_STATE_DIR` | `$HOME/.omp` | Persistent agent state directory |
| `SSH_DIR` | `$HOME/.ssh` | Host SSH directory (mounted read-only for commit signing) |
| `GIT_SIGNING_KEY` | `/root/.ssh/id_ed25519` | SSH key path for commit signing |
| `RESOURCE_CPUS` | `2.0` | CPU limit |
| `RESOURCE_MEMORY` | `4g` | Memory limit |

## CLI Commands

Once installed, three commands are available from anywhere:

### `omp-docker [args]`
Run the OMP agent in the current directory. All arguments are forwarded to the agent.

```sh
omp-docker                          # start agent interactively
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
make docker.clean    # remove all project images
make docker.update   # rebuild from update stage (cache-busting)
make docker.ls       # list project images
make uninstall       # remove CLI wrapper scripts
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
              └─ exec omp [args]
```

`omp update` runs at image build time (`RUN omp update` in the Dockerfile), not at container startup.

| File | Purpose |
|---|---|
| `Makefile` | Primary CLI interface |
| `Dockerfile` | Container image (oven/bun:1.3). `omp update` runs at build time. |
| `compose.yaml` | Service config: mounts, env, capabilities, network, resource limits |
| `entrypoint.sh` | Copies SSH keys with correct perms, dispatches commands via `exec` |
| `.env.default.properties` | Committed default configuration |
| `.dockerignore` | Excludes .git, docs, markdown from build context |

## Security

- **Resource limits**: CPU and memory capped via `deploy.resources.limits`
- **Network isolation**: Custom bridge network with controlled egress
- **Capabilities**: `NET_ADMIN` and `NET_RAW` are required for iptables-based egress control (agent network sandboxing)
- **Credential isolation**: Git identity via `~/.gitconfig` (mounted read-only, auto-detected); `~/.ssh` mounted read-only for commit signing
- **Cache persistence**: Named volumes for pip/npm caches

## Contributing

1. Fork and create a feature branch
2. Make changes to the Dockerfile, Makefile, or compose config
3. Test with `make docker.run echo "ok"`
4. Submit a pull request
