#!/usr/bin/env bash
set -euo pipefail

# Node Version Manager provisioning for user 'vagrant'
NVM_VERSION="v0.39.7"
NVM_DIR="/home/vagrant/.nvm"
USER_SHELL_RC="/home/vagrant/.bashrc"

# Create nvm dir and set ownership (idempotent)
mkdir -p "$NVM_DIR"
chown -R vagrant:vagrant "$NVM_DIR"

# Install nvm only if not already present
if ! sudo -u vagrant -H bash -lc 'command -v nvm >/dev/null 2>&1'; then
  echo "Installing nvm ${NVM_VERSION} for user 'vagrant'..."
  sudo -u vagrant -H bash -lc "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
else
  echo "nvm already installed; skipping."
fi

# Ensure nvm is loaded in the user's shell (idempotent append)
if ! sudo -u vagrant -H bash -lc "grep -q 'NVM_DIR' '${USER_SHELL_RC}'"; then
  echo 'export NVM_DIR="$HOME/.nvm"' >> "${USER_SHELL_RC}"
  echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "${USER_SHELL_RC}"
  echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "${USER_SHELL_RC}"
  chown vagrant:vagrant "${USER_SHELL_RC}"
fi

# Load nvm in this session and install latest LTS if not present
if sudo -u vagrant -H bash -lc 'command -v nvm >/dev/null 2>&1'; then
  sudo -u vagrant -H bash -lc '
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    if ! nvm ls --no-colors | grep -q "->.*lts"; then
      nvm install --lts
      nvm alias default lts/*
    fi
  '
fi
