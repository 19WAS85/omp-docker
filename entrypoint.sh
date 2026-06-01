#!/usr/bin/env bash
set -uo pipefail

# Fix SSH config permissions (host mount is :ro with 644; SSH requires ≤ 600)
if [[ -d /root/.ssh && -f /root/.ssh/config ]]; then
  cp -r /root/.ssh /tmp/.ssh
  chmod 600 /tmp/.ssh/config /tmp/.ssh/id_* 2>/dev/null
  export GIT_SSH_COMMAND="ssh -F /tmp/.ssh/config -o StrictHostKeyChecking=accept-new"
fi

# Fix locale: host may pass LC_ALL=en_US.UTF-8 which isn't installed in container.
# Fall back to C.UTF-8 (always available on Debian) to silence the warning.
if [[ -n "${LC_ALL:-}" ]] && ! locale -a 2>/dev/null | grep -qi "^${LC_ALL}$"; then
  export LC_ALL=C.UTF-8
fi

# Configure git via a writable config file (host gitconfig is mounted :ro).
# GIT_CONFIG_GLOBAL overrides ~/.gitconfig lookup; --file writes to that path.
export GIT_CONFIG_GLOBAL=/tmp/.gitconfig
touch "$GIT_CONFIG_GLOBAL"
git config --file "$GIT_CONFIG_GLOBAL" safe.directory /work
git config --file "$GIT_CONFIG_GLOBAL" gpg.format ssh
git config --file "$GIT_CONFIG_GLOBAL" user.signingkey "${GIT_SIGNING_KEY:-/root/.ssh/id_ed25519}"
git config --file "$GIT_CONFIG_GLOBAL" commit.gpgsign true

# Dockerfile has CMD ["omp"], so docker compose run --rm omp passes "omp" as $1.
# Strip it so we don't run `omp omp`. Shell names (bash, sh, ...) exec directly
# to preserve the `docker compose run --rm omp bash` escape hatch.
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "omp" ]]; then
    shift
    # If only "omp" was passed ($# now 0), fall through to default `exec omp`.
    # If more args remain (e.g. omp --resume), pass them to omp.
    if [[ $# -gt 0 ]]; then
      exec omp "$@"
    fi
  else
    case "$1" in
      bash|sh|ash|python|python3|node|bun)
        exec "$@"
        ;;
      *)
        exec omp "$@"
        ;;
    esac
  fi
fi

# Default: run the agent with no arguments
exec omp
