#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_SCRIPT="${ROOT_DIR}/deploy/vault/scripts/run-local-macos.sh"
APISIX_SCRIPT="${ROOT_DIR}/deploy/apisix/scripts/run-local-macos.sh"
OPENCLAW_SCRIPT="${ROOT_DIR}/scripts/run-openclaw-local.sh"

usage() {
  cat <<'EOF'
Usage: scripts/run-ai-local-stack.sh <up|down|restart|status>
EOF
}

run_step() {
  local script="$1"
  local action="$2"
  "$script" "$action"
}

status() {
  run_step "$VAULT_SCRIPT" status || true
  run_step "$APISIX_SCRIPT" status || true
  run_step "$OPENCLAW_SCRIPT" status || true
}

ACTION="${1:-}"
[[ -n "$ACTION" ]] || {
  usage
  exit 1
}

case "$ACTION" in
  up)
    run_step "$VAULT_SCRIPT" up
    run_step "$OPENCLAW_SCRIPT" up
    run_step "$APISIX_SCRIPT" up
    status
    ;;
  down)
    run_step "$APISIX_SCRIPT" down || true
    run_step "$OPENCLAW_SCRIPT" down || true
    run_step "$VAULT_SCRIPT" down || true
    ;;
  restart)
    run_step "$APISIX_SCRIPT" down || true
    run_step "$OPENCLAW_SCRIPT" down || true
    run_step "$VAULT_SCRIPT" down || true
    run_step "$VAULT_SCRIPT" up
    run_step "$OPENCLAW_SCRIPT" up
    run_step "$APISIX_SCRIPT" up
    status
    ;;
  status)
    status
    ;;
  *)
    usage
    exit 1
    ;;
esac
