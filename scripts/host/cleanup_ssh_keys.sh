
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  cleanup_ssh_keys.sh --key-dir <directory> --key-name <keyname>

Removes the generated SSH private/public key pair if present.
USAGE
}

log() { printf '%s\n' "$*" >&2; }

abspath() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$p"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import os, sys
print(os.path.abspath(sys.argv[1]))
PY
"$p"
  else
    [[ "$p" = /* ]] && printf '%s\n' "$p" || printf '%s\n' "$(pwd)/$p"
  fi
}

KEY_DIR=""
KEY_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key-dir) KEY_DIR="${2:-}"; shift 2 ;;
    --key-name) KEY_NAME="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) log "Unknown argument: $1"; usage; exit 2 ;;
  esac
done

if [[ -z "$KEY_DIR" || -z "$KEY_NAME" ]]; then
  log "Error: --key-dir and --key-name are required."
  usage; exit 2
fi

KEY_DIR_ABS="$(abspath "$KEY_DIR")"
KEY_PATH="${KEY_DIR_ABS}/${KEY_NAME}"
PUB_PATH="${KEY_PATH}.pub"

# Remove keys if they exist
rm -f "$KEY_PATH" "$PUB_PATH"

# If directory is empty after removal, you may optionally remove it
if [[ -d "$KEY_DIR_ABS" && -z "$(ls -A "$KEY_DIR_ABS")" ]]; then
  rmdir "$KEY_DIR_ABS" || true
fi

log "Cleaned up: $KEY_PATH and $PUB_PATH (if they existed)"
