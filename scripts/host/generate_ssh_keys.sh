#!/usr/bin/env bash
set -euo pipefail

# Generates an ed25519 SSH key for Vagrant-style usage, idempotently.
# Usage:
#   ./generate_ssh_keys.sh --key-dir "<dir>" --key-name "<name>" [--passphrase "<value>"]
#
# Behavior:
#   - Creates the directory if missing.
#   - Skips generation if both private and public keys already exist.
#   - Uses ssh-keygen from PATH.
#   - Sets comment to "vagrant@<hostname>".
#   - Uses -a 64 (key derivation rounds) and ed25519.
#   - Sets permissions: private key 600, public key 644.
#   - Best-effort chown to current user (robust on Linux/macOS/Git Bash/WSL).

usage() {
  cat <<'USAGE'
Usage:
  generate_ssh_keys.sh --key-dir <directory> --key-name <keyname> [--passphrase <passphrase>]

Required:
  --key-dir       Directory where keys will be stored (relative or absolute).
  --key-name      Base filename for the key (without .pub).

Optional:
  --passphrase    Passphrase for the private key. Default: empty (suitable for Vagrant).
  -h, --help      Show this help and exit.
USAGE
}

log() { printf '%s\n' "$*" >&2; }

# Cross-platform absolute path resolution
abspath() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$p"
  elif command -v python3 >/dev/null 2>&1; then
    # Use Python for robust normalization (works on POSIX and Git Bash paths)
    python3 - "$p" <<'PY'
import os, sys
print(os.path.abspath(sys.argv[1]))
PY
  else
    # Simple fallback
    if [[ "$p" = /* ]]; then
      printf '%s\n' "$p"
    else
      printf '%s\n' "$(pwd)/$p"
    fi
  fi
}

KEY_DIR=""
KEY_NAME=""
PASSPHRASE="${PASSPHRASE:-}"  # allow env override if desired

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key-dir) KEY_DIR="${2:-}"; shift 2 ;;
    --key-name) KEY_NAME="${2:-}"; shift 2 ;;
    --passphrase) PASSPHRASE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) log "Unknown argument: $1"; usage; exit 2 ;;
  esac
done

if [[ -z "${KEY_DIR}" || -z "${KEY_NAME}" ]]; then
  log "Error: --key-dir and --key-name are required."
  usage
  exit 2
fi

# Ensure ssh-keygen is available
if ! command -v ssh-keygen >/dev/null 2>&1; then
  log "Error: ssh-keygen not found in PATH."
  exit 1
fi
SSH_KEYGEN="$(command -v ssh-keygen)"

# Normalize the key directory to an absolute path and ensure it exists
KEY_DIR_ABS="$(abspath "$KEY_DIR")"
mkdir -p "$KEY_DIR_ABS"

# Paths
KEY_PATH="${KEY_DIR_ABS}/${KEY_NAME}"
PUB_PATH="${KEY_PATH}.pub"

# Idempotency: if both files exist, skip
if [[ -f "$KEY_PATH" && -f "$PUB_PATH" ]]; then
  log "SSH key already exists at ${KEY_PATH}; skipping generation."
  exit 0
fi

# Prepare metadata
HOSTNAME_STR="$(hostname 2>/dev/null || uname -n)"
COMMENT="vagrant@${HOSTNAME_STR}"

log "Using ssh-keygen: $SSH_KEYGEN"
log "KeyDir: $KEY_DIR_ABS"
log "KeyName: $KEY_NAME"
log "KeyPath: $KEY_PATH"
log "Requested passphrase length: ${#PASSPHRASE}"

# Use a restrictive umask while creating the key
UMASK_OLD="$(umask)"
umask 077

# Generate keypair
if [[ -z "$PASSPHRASE" ]]; then
  "$SSH_KEYGEN" -t ed25519 -a 64 -f "$KEY_PATH" -C "$COMMENT" -N "" >/dev/null
else
  "$SSH_KEYGEN" -t ed25519 -a 64 -f "$KEY_PATH" -C "$COMMENT" -N "$PASSPHRASE" >/dev/null
fi

# Restore umask
umask "$UMASK_OLD"

# Permissions hardening
[[ -f "$KEY_PATH" ]] && chmod 600 "$KEY_PATH" || true
[[ -f "$PUB_PATH" ]] && chmod 644 "$PUB_PATH" || true

# Ownership: handle environments where USER may be unset (Git Bash/MSYS/WSL)
# Prefer SUDO_USER, then USER/LOGNAME, then id -un, then whoami
CURRENT_USER="${SUDO_USER:-${USER:-${LOGNAME:-}}}"
if [[ -z "${CURRENT_USER}" ]]; then
  if command -v id >/dev/null 2>&1; then
    CURRENT_USER="$(id -un 2>/dev/null || true)"
  fi
fi
if [[ -z "${CURRENT_USER}" ]] && command -v whoami >/dev/null 2>&1; then
  CURRENT_USER="$(whoami 2>/dev/null || true)"
fi

if [[ -n "${CURRENT_USER}" ]] && command -v id >/dev/null 2>&1 && id "$CURRENT_USER" >/dev/null 2>&1; then
  chown "$CURRENT_USER":"$CURRENT_USER" "$KEY_PATH" "$PUB_PATH" || true
fi

log "SSH key generated: $KEY_PATH"