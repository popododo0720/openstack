#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# SSH 대기
echo "helm1 SSH 대기..."
until sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@10.250.254.21 'echo ok' 2>/dev/null; do
    sleep 10
done
echo "SSH OK"

# kubespray 실행
ansible-playbook \
    -i "${SCRIPT_DIR}/kubespray/inventory/helm-cluster/inventory.ini" \
    "${SCRIPT_DIR}/kubespray/cluster.yml" \
    -b 2>&1 | tee -a "${SCRIPT_DIR}/ansible.log"
