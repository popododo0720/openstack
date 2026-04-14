#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIRGAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INVENTORY="${INVENTORY:-${AIRGAP_DIR}/inventory.ini}"
REMOTE_USER="${REMOTE_USER:-root}"
KOLLA_VENV_PATH="${KOLLA_VENV_PATH:-/root/kolla-venv}"
MULTINODE_PATH="${MULTINODE_PATH:-/root/multinode}"
LOG_DIR="${LOG_DIR:-${AIRGAP_DIR}/logs}"

usage() {
  cat <<'EOF'
Usage:
  ./kolla-run.sh <action> [kolla-ansible args...]

Actions:
  pull | prechecks | deploy | deploy-containers | reconfigure | post-deploy | stop | upgrade

Examples:
  ./kolla-run.sh pull
  ./kolla-run.sh reconfigure --tags cinder
  ./kolla-run.sh deploy --limit stack1
EOF
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "missing file: ${path}" >&2
    exit 1
  fi
}

inventory_host_ip() {
  local host_name="$1"
  awk -v target="${host_name}" '
    /^\[all\]$/ { in_all=1; next }
    /^\[/ && in_all { exit }
    in_all && $1 == target {
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^ansible_host=/) {
          sub(/^ansible_host=/, "", $i)
          print $i
          exit
        }
      }
    }
  ' "${INVENTORY}"
}

require_file "${INVENTORY}"

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

ACTION="$1"
shift

case "${ACTION}" in
  pull|prechecks|deploy|deploy-containers|reconfigure|post-deploy|stop|upgrade) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "unsupported action: ${ACTION}" >&2
    usage
    exit 1
    ;;
esac

STACK1_HOST="${STACK1_HOST:-$(inventory_host_ip stack1)}"
if [[ -z "${STACK1_HOST}" ]]; then
  echo "failed to resolve stack1 ansible_host from ${INVENTORY}" >&2
  exit 1
fi

mkdir -p "${LOG_DIR}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/kolla-${ACTION}-${TIMESTAMP}.log"

echo "[INFO] inventory: ${INVENTORY}"
echo "[INFO] stack1: ${STACK1_HOST}"
echo "[INFO] action: ${ACTION}"
echo "[INFO] log: ${LOG_FILE}"

ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "${REMOTE_USER}@${STACK1_HOST}" \
  bash -s -- "${ACTION}" "${KOLLA_VENV_PATH}" "${MULTINODE_PATH}" "$@" <<'EOF' | tee "${LOG_FILE}"
set -euo pipefail

action="$1"
venv_path="$2"
multinode_path="$3"
shift 3

if [[ ! -f "${venv_path}/bin/activate" ]]; then
  echo "missing Kolla venv: ${venv_path}" >&2
  exit 1
fi

if [[ ! -f "${multinode_path}" ]]; then
  echo "missing remote inventory: ${multinode_path}" >&2
  exit 1
fi

source "${venv_path}/bin/activate"
echo "[REMOTE] host=$(hostname -s) action=${action} inventory=${multinode_path}"
exec stdbuf -oL kolla-ansible "${action}" -i "${multinode_path}" "$@"
EOF

status=${PIPESTATUS[0]}
if [[ ${status} -ne 0 ]]; then
  echo "[ERROR] kolla-ansible ${ACTION} failed with status ${status}" >&2
  exit "${status}"
fi

echo "[INFO] completed: ${ACTION}"
