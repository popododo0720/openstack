#!/bin/bash
# =============================================================
# OpenStack-Helm 전체 배포 스크립트
# VM 생성 → kubespray → OSH 01~06 순차 실행
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KUBESPRAY_DIR="${SCRIPT_DIR}/kubespray"
INVENTORY="${SCRIPT_DIR}/inventory.ini"
LOG="${SCRIPT_DIR}/ansible.log"
HELM1_IP="10.250.254.21"

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $*"; }
err() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*"; }

# 실행 시간 기록
SECONDS=0

# =============================================================
# Step 0: VM 재생성
# =============================================================
log "========== Step 0: VM 재생성 =========="

if virsh list --all --name 2>/dev/null | grep -q "^helm1$"; then
    log "기존 helm1 VM 삭제 중..."
    bash "${SCRIPT_DIR}/vm-destroy.sh" || true
    sleep 3
fi

log "helm1 VM 생성 중..."
bash "${SCRIPT_DIR}/vm-create.sh"

# =============================================================
# Step 1: SSH 대기 (cloud-init 완료까지)
# =============================================================
log "========== Step 1: SSH 대기 =========="
log "helm1 (${HELM1_IP}) SSH 접속 대기 중..."

RETRY=0
MAX_RETRY=60
until sshpass -p 'root' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${HELM1_IP} 'echo ok' 2>/dev/null; do
    RETRY=$((RETRY + 1))
    if [ $RETRY -ge $MAX_RETRY ]; then
        err "SSH 접속 실패 (${MAX_RETRY}회 시도). VM 상태 확인 필요."
        exit 1
    fi
    echo -n "."
    sleep 10
done
echo ""

log "SSH 접속 성공. cloud-init 완료 대기 (30초)..."
sleep 30

# cloud-init 완료 확인
sshpass -p 'root' ssh -o StrictHostKeyChecking=no root@${HELM1_IP} \
    'cloud-init status --wait 2>/dev/null || true'
log "cloud-init 완료."

# =============================================================
# Step 2: Kubespray (K8s 배포)
# =============================================================
log "========== Step 2: Kubespray (K8s 배포) =========="

if [ ! -d "${KUBESPRAY_DIR}" ]; then
    err "kubespray 디렉토리 없음: ${KUBESPRAY_DIR}"
    err "git clone https://github.com/kubernetes-sigs/kubespray.git -b release-2.30 ${KUBESPRAY_DIR}"
    exit 1
fi

log "kubespray 시작..."
cd "${KUBESPRAY_DIR}"
ansible-playbook -i inventory/helm-cluster/inventory.ini cluster.yml -b 2>&1 | tee -a "${LOG}"

log "kubespray 완료. kubectl 확인..."
sshpass -p 'root' ssh -o StrictHostKeyChecking=no root@${HELM1_IP} 'kubectl get nodes'

# =============================================================
# Step 3~8: OSH 배포 (01~06 순차 실행)
# =============================================================
cd "${SCRIPT_DIR}"

PLAYBOOKS=(
    "01-k8s-prerequisites.yml"
    "02-rook-ceph.yml"
    "03-osh-prerequisites.yml"
    "04-openstack-backend.yml"
    "05-openstack-core.yml"
    "06-openstack-extra.yml"
)

STEP=3
for playbook in "${PLAYBOOKS[@]}"; do
    log "========== Step ${STEP}: ${playbook} =========="
    ansible-playbook -i "${INVENTORY}" "${playbook}" 2>&1 | tee -a "${LOG}"

    if [ $? -ne 0 ]; then
        err "${playbook} 실패! ansible.log 확인."
        exit 1
    fi

    log "${playbook} 완료."
    STEP=$((STEP + 1))
done

# =============================================================
# 완료
# =============================================================
ELAPSED=$SECONDS
MINS=$((ELAPSED / 60))
SECS=$((ELAPSED % 60))

echo ""
log "================================================"
log "  전체 배포 완료! (소요시간: ${MINS}분 ${SECS}초)"
log "================================================"
log ""
log "  Skyline:  https://192.168.0.60"
log "  계정:     coremax / coremax1@#"
log ""
log "  다음 단계: Terraform"
log "    cd ${SCRIPT_DIR}/terraform/01-base && terraform init && terraform apply"
log "    cd ${SCRIPT_DIR}/terraform/02-instance && terraform init && terraform apply"
log "================================================"
