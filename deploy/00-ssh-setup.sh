#!/bin/bash
set -e

HOSTS=("10.250.254.11" "10.250.254.12" "10.250.254.13")
NAMES=("stack1" "stack2" "stack3")
ROOT_PASS="root"

# Ceph OSD 디스크 (추가 시 여기에)
OSD_DEVICES=("/dev/sdb")

# 1. SSH 키 생성 (없으면)
if [ ! -f /root/.ssh/id_rsa ]; then
    echo "[1/4] SSH 키 생성..."
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -q
else
    echo "[1/4] SSH 키 이미 존재"
fi

# 2. known_hosts 정리 + SSH 키 배포
echo "[2/4] SSH 키 배포 (관리 네트워크)..."
for i in ${!HOSTS[@]}; do
    host=${HOSTS[$i]}
    name=${NAMES[$i]}
    ssh-keygen -f /root/.ssh/known_hosts -R $host 2>/dev/null || true
    echo "  → $name ($host)"
    sshpass -p "$ROOT_PASS" ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@$host
done

# 3. 연결 테스트
echo "[3/4] SSH 연결 테스트..."
for i in ${!HOSTS[@]}; do
    host=${HOSTS[$i]}
    name=${NAMES[$i]}
    result=$(ssh -o StrictHostKeyChecking=no root@$host "hostname" 2>/dev/null)
    if [ "$result" = "$name" ]; then
        echo "  ✓ $name ($host) OK"
    else
        echo "  ✗ $name ($host) FAILED"
        exit 1
    fi
done

# 4. OSD 디스크 초기화
echo "[4/4] OSD 디스크 초기화 (Ceph용)..."
for i in ${!HOSTS[@]}; do
    host=${HOSTS[$i]}
    name=${NAMES[$i]}
    for dev in ${OSD_DEVICES[@]}; do
        echo "  → $name ($host) $dev 초기화"
        ssh -o StrictHostKeyChecking=no root@$host "dmsetup remove_all 2>/dev/null; vgremove -f $(vgs --noheadings -o vg_name 2>/dev/null | grep ceph) 2>/dev/null; wipefs -af $dev; sgdisk --zap-all $dev; dd if=/dev/zero of=$dev bs=1M count=100 2>/dev/null; partprobe $dev; echo done"
        echo "    OK"
    done
done

echo ""
echo "완료."
