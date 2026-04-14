#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIRGAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INVENTORY="${INVENTORY:-${AIRGAP_DIR}/inventory.ini}"
REMOTE_USER="${REMOTE_USER:-root}"

usage() {
  cat <<'EOF'
Usage:
  ./service-reconfig.sh <service> [extra kolla args...]

Examples:
  ./service-reconfig.sh cinder
  ./service-reconfig.sh neutron --limit stack1
  ./service-reconfig.sh nova --skip-check
EOF
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

inventory_all_hosts() {
  awk '
    /^\[all\]$/ { in_all=1; next }
    /^\[/ && in_all { exit }
    in_all && NF {
      ip=""
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^ansible_host=/) {
          ip=$i
          sub(/^ansible_host=/, "", ip)
          print $1, ip
          break
        }
      }
    }
  ' "${INVENTORY}"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

service="$1"
shift

skip_check=0
extra_args=()
for arg in "$@"; do
  if [[ "${arg}" == "--skip-check" ]]; then
    skip_check=1
  else
    extra_args+=("${arg}")
  fi
done

case "${service}" in
  cinder)
    tags="cinder"
    pattern='cinder_|tgtd|iscsid'
    openstack_check='openstack volume service list -f table && echo && openstack volume type list -f table'
    ;;
  glance)
    tags="glance"
    pattern='glance_'
    openstack_check='openstack image list -f table'
    ;;
  nova)
    tags="nova"
    pattern='nova_'
    openstack_check='openstack compute service list -f table && echo && openstack hypervisor list -f table'
    ;;
  neutron)
    tags="neutron"
    pattern='neutron_|ovn_|openvswitch'
    openstack_check='openstack network agent list -f table'
    ;;
  keystone)
    tags="keystone"
    pattern='keystone|fernet'
    openstack_check='openstack endpoint list -c "Service Name" -c Interface -c URL -f table'
    ;;
  horizon)
    tags="horizon"
    pattern='horizon'
    openstack_check='openstack endpoint list -c "Service Name" -c Interface -c URL -f table'
    ;;
  heat)
    tags="heat"
    pattern='heat_'
    openstack_check='openstack orchestration service list -f table'
    ;;
  masakari)
    tags="masakari"
    pattern='masakari'
    openstack_check='openstack segment list -f table'
    ;;
  *)
    tags="${service}"
    pattern="${service}"
    openstack_check=''
    ;;
esac

echo "[INFO] service: ${service}"
echo "[INFO] tags: ${tags}"
"${SCRIPT_DIR}/kolla-run.sh" reconfigure --tags "${tags}" "${extra_args[@]}"

if [[ ${skip_check} -eq 1 ]]; then
  exit 0
fi

echo
echo "== Container Status =="
while read -r host_name host_ip; do
  [[ -z "${host_name}" || -z "${host_ip}" ]] && continue
  echo "-- ${host_name} (${host_ip}) --"
  ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${REMOTE_USER}@${host_ip}" \
    bash -s -- "${pattern}" <<'EOF'
set -euo pipefail
pattern="$1"
docker ps --format '{{.Names}}\t{{.Status}}' | grep -E "${pattern}" || echo "no matching containers"
EOF
  echo
done < <(inventory_all_hosts)

if [[ -n "${openstack_check}" ]]; then
  stack1_host="$(inventory_host_ip stack1)"
  if [[ -n "${stack1_host}" ]]; then
    echo "== OpenStack Status =="
    ssh \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      "${REMOTE_USER}@${stack1_host}" \
      bash -s -- "${openstack_check}" <<'EOF'
set -euo pipefail
if [[ -f /root/kolla-venv/bin/activate ]]; then
  source /root/kolla-venv/bin/activate
fi
for openrc in \
  /etc/kolla/admin-openrc.sh \
  /etc/kolla/admin-openrc-system.sh \
  /root/admin-openrc.sh \
  /root/admin-openrc-system.sh; do
  if [[ -f "${openrc}" ]]; then
    source "${openrc}"
    eval "$1"
    exit 0
  fi
done
echo "missing admin-openrc file" >&2
exit 1
EOF
  fi
fi
