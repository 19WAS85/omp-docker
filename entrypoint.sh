#!/usr/bin/env bash
set -uo pipefail

# Fix SSH config permissions (host mount is :ro with 644; SSH requires ≤ 600)
if [[ -d /root/.ssh && -f /root/.ssh/config ]]; then
  cp -r /root/.ssh /tmp/.ssh
  chmod 600 /tmp/.ssh/config /tmp/.ssh/id_* 2>/dev/null
  export GIT_SSH_COMMAND="ssh -F /tmp/.ssh/config -o StrictHostKeyChecking=accept-new"
fi

# Configure git for container use
git config --global safe.directory /work
git config --global gpg.format ssh
git config --global user.signingkey "${GIT_SIGNING_KEY:-/root/.ssh/id_ed25519}"
git config --global commit.gpgsign true

# If arguments are provided, exec them directly.
# This handles: entrypoint omp, entrypoint bash, entrypoint sh, etc.
if [[ $# -gt 0 ]]; then
  exec "$@"
fi

# Default: run the agent
exec omp
