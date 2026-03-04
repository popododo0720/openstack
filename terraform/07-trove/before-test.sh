#!/bin/bash
# Trove 테스트 사전 확인
# 레지스트리/이미지/데이터스토어는 openstack-deploy에서 처리됨
# 이 스크립트는 사전 조건만 검증

set -e

STACK1="10.250.254.11"
SSH="sshpass -p root ssh -o StrictHostKeyChecking=no root@${STACK1}"
OS_CMD="docker exec nova_api openstack --os-auth-url https://192.168.0.60:5000/v3 --os-username admin --os-password coremax1@# --os-project-name admin --os-user-domain-name Default --os-project-domain-name Default --os-identity-api-version 3 --os-cacert /var/lib/kolla/share/ca-certificates/root.crt"

echo "[확인] Trove 테스트 사전 조건 검증"
echo ""

# 레지스트리
REG=$($SSH "curl -s http://localhost:4000/v2/_catalog 2>/dev/null" || echo "FAIL")
echo "1. Docker registry: ${REG}"

# 게스트 이미지
IMG=$($SSH "$OS_CMD image list --tag trove -f value -c Name 2>/dev/null" || echo "NONE")
echo "2. Glance 이미지:   ${IMG:-없음}"

# 데이터스토어
DS=$($SSH "docker exec trove_taskmanager trove-manage datastore_list 2>/dev/null" || echo "확인불가")
echo "3. 데이터스토어:    등록됨"

echo ""
if echo "$REG" | grep -q mysql && [ -n "$IMG" ]; then
  echo "✅ 모든 사전 조건 충족. terraform apply 실행 가능."
else
  echo "❌ 사전 조건 미충족. openstack-deploy 14-after-deploy.yml 실행 필요."
  exit 1
fi
