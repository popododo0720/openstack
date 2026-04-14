#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIRGAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INVENTORY="${INVENTORY:-${AIRGAP_DIR}/inventory.ini}"
REMOTE_USER="${REMOTE_USER:-root}"

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

if [[ ! -f "${INVENTORY}" ]]; then
  echo "missing inventory: ${INVENTORY}" >&2
  exit 1
fi

STACK1_HOST="${STACK1_HOST:-$(inventory_host_ip stack1)}"
if [[ -z "${STACK1_HOST}" ]]; then
  echo "failed to resolve stack1 ansible_host from ${INVENTORY}" >&2
  exit 1
fi

ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "${REMOTE_USER}@${STACK1_HOST}" \
  bash -s <<'EOF'
set -euo pipefail

failures=0

run_check() {
  local title="$1"
  shift
  echo
  echo "== ${title} =="
  if ! bash -lc "$*"; then
    failures=$((failures + 1))
    echo "[FAIL] ${title}" >&2
  fi
}

if [[ -f /root/kolla-venv/bin/activate ]]; then
  source /root/kolla-venv/bin/activate
else
  echo "missing /root/kolla-venv/bin/activate" >&2
  exit 1
fi

openrc_found=0
for openrc in \
  /etc/kolla/admin-openrc.sh \
  /etc/kolla/admin-openrc-system.sh \
  /root/admin-openrc.sh \
  /root/admin-openrc-system.sh; do
  if [[ -f "${openrc}" ]]; then
    source "${openrc}"
    openrc_found=1
    break
  fi
done

if [[ ${openrc_found} -ne 1 ]]; then
  echo "missing admin-openrc file" >&2
  exit 1
fi

echo "host: $(hostname -s)"
echo "date: $(date -Is)"

run_check "Ceph" 'ceph -s'
run_check "Endpoints" 'openstack endpoint list -c "Service Name" -c Interface -c URL -f table'
run_check "Hypervisors" 'openstack hypervisor list -f table'
run_check "Compute Services" 'openstack compute service list -f table'
run_check "Network Agents" 'openstack network agent list -f table'
run_check "Volume Services" 'openstack volume service list -f table'
run_check "Volume Types" 'openstack volume type list -f table'
run_check "Images" 'openstack image list -f table'
run_check "Core Containers" "docker ps --format '{{.Names}}\t{{.Status}}' | grep -E 'keystone|glance|nova_|neutron_|cinder_|rabbitmq|mariadb|haproxy|ovn_'"

if [[ ${failures} -ne 0 ]]; then
  echo
  echo "[ERROR] postcheck failed: ${failures} check(s)" >&2
  exit 1
fi

echo
echo "[INFO] postcheck completed successfully"
EOF
