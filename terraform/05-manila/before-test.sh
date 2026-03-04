#!/bin/bash
# Manila 테스트 전 사전 설정
# - share type 생성 (terraform provider v3에서 미지원)

set -e

STACK1="10.250.254.11"
SSH="sshpass -p root ssh -o StrictHostKeyChecking=no root@${STACK1}"
OS_CMD="docker exec nova_api openstack --os-auth-url https://192.168.0.60:5000/v3 --os-username admin --os-password coremax1@# --os-project-name admin --os-user-domain-name Default --os-project-domain-name Default --os-identity-api-version 3 --os-cacert /var/lib/kolla/share/ca-certificates/root.crt"

echo "[1/1] Share type 'cephfs-type' 생성..."
EXISTING=$($SSH "$OS_CMD share type list -f value -c Name 2>/dev/null" | grep -w cephfs-type || true)
if [ -n "$EXISTING" ]; then
  echo "  -> 이미 존재함. 스킵."
else
  $SSH "$OS_CMD share type create cephfs-type false --extra-specs share_backend_name=CEPHFS1" >/dev/null
  echo "  -> 생성 완료."
fi

echo "완료. terraform apply 실행 가능."
