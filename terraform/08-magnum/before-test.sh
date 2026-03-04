#!/bin/bash
# Magnum 테스트 전 사전 설정
# - Fedora CoreOS 이미지 다운로드 및 Glance 업로드
#
# ⚠️  다운로드 ~700MB (압축) → ~2GB (해제) — 시간 소요
# ⚠️  Magnum Heat driver는 Fedora CoreOS만 지원 (Ignition 기반)
#    Ubuntu/CentOS 사용 불가 (CAPI driver 필요, 별도 K8s 관리 클러스터 필요)

set -e

STACK1="10.250.254.11"
SSH="sshpass -p root ssh -o StrictHostKeyChecking=no root@${STACK1}"
OS_CMD="docker exec nova_api openstack --os-auth-url https://192.168.0.60:5000/v3 --os-username admin --os-password coremax1@# --os-project-name admin --os-user-domain-name Default --os-project-domain-name Default --os-identity-api-version 3 --os-cacert /var/lib/kolla/share/ca-certificates/root.crt"

IMAGE_NAME="fedora-coreos"

echo "========================================"
echo " Magnum 사전 설정"
echo "========================================"

# ── [1/1] Fedora CoreOS 이미지 업로드 ──
echo ""
echo "[1/1] Fedora CoreOS 이미지 확인..."
EXISTING=$($SSH "$OS_CMD image list -f value -c Name 2>/dev/null" | grep -w "${IMAGE_NAME}" || true)
if [ -n "$EXISTING" ]; then
  echo "  -> 이미지 '${IMAGE_NAME}' 이미 존재함. 스킵."
else
  # 최신 stable FCOS 버전 URL 자동 감지
  echo "  -> 최신 stable 버전 확인 중..."
  FCOS_URL=$($SSH "curl -s https://builds.coreos.fedoraproject.org/streams/stable.json" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['architectures']['x86_64']['artifacts']['openstack']['formats']['qcow2.xz']['disk']['location'])")

  if [ -z "$FCOS_URL" ]; then
    echo "  !! stable stream 자동 감지 실패. fallback URL 사용."
    FCOS_URL="https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/40.20240906.3.0/x86_64/fedora-coreos-40.20240906.3.0-openstack.x86_64.qcow2.xz"
  fi
  echo "  -> URL: ${FCOS_URL}"

  echo "  -> 다운로드 중 (~700MB compressed)..."
  $SSH "curl -L --progress-bar -o /tmp/fcos.qcow2.xz '${FCOS_URL}'"

  echo "  -> 압축 해제 중 (xz → qcow2, ~2GB)..."
  $SSH "xz -d /tmp/fcos.qcow2.xz"

  echo "  -> 컨테이너에 복사 중..."
  $SSH "docker cp /tmp/fcos.qcow2 nova_api:/tmp/fcos.qcow2"

  echo "  -> Glance 업로드 중..."
  $SSH "$OS_CMD image create ${IMAGE_NAME} \
    --disk-format qcow2 --container-format bare \
    --file /tmp/fcos.qcow2 \
    --public \
    --property os_distro=fedora-coreos" >/dev/null

  echo "  -> 임시 파일 정리..."
  $SSH "rm -f /tmp/fcos.qcow2"
  $SSH "docker exec nova_api rm -f /tmp/fcos.qcow2"

  echo "  -> 업로드 완료."
fi

echo ""
echo "========================================"
echo " 완료. terraform apply 실행 가능."
echo "========================================"
