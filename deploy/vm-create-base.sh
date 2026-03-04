#!/bin/bash
# Ubuntu 베이스 이미지 생성 스크립트
# 현재 stack1 VM을 베이스 이미지로 복사

IMAGE_DIR="/DATA/libvirt/images"
BASE_IMAGE="${IMAGE_DIR}/ubuntu-base.qcow2"
SOURCE_VM="stack1"

echo "=== 베이스 이미지 생성 ==="
echo "소스 VM: $SOURCE_VM"
echo "대상: $BASE_IMAGE"
echo ""

# VM 상태 확인
if virsh list --name | grep -q "^${SOURCE_VM}$"; then
    echo "경고: $SOURCE_VM 이 실행 중입니다."
    echo "깨끗한 베이스 이미지를 위해 VM을 종료하고 다음을 수행하세요:"
    echo "1. VM 내에서 클린 상태 만들기:"
    echo "   - /etc/machine-id 삭제"
    echo "   - SSH host keys 삭제"
    echo "   - 네트워크 설정 초기화"
    echo "   - 로그/히스토리 정리"
    echo "2. VM 종료: virsh shutdown $SOURCE_VM"
    echo "3. 이 스크립트 다시 실행"
    echo ""
    read -p "그래도 실행 중인 VM에서 복사하시겠습니까? (y/N): " answer
    if [ "$answer" != "y" ]; then
        exit 1
    fi
fi

# 기존 베이스 이미지 백업
if [ -f "$BASE_IMAGE" ]; then
    echo "기존 베이스 이미지 백업: ${BASE_IMAGE}.bak"
    mv "$BASE_IMAGE" "${BASE_IMAGE}.bak"
fi

# 복사
echo "디스크 복사 중... (시간이 걸릴 수 있습니다)"
cp "${IMAGE_DIR}/${SOURCE_VM}.qcow2" "$BASE_IMAGE"

# 권한 설정
chown libvirt-qemu:kvm "$BASE_IMAGE"
chmod 644 "$BASE_IMAGE"

echo ""
echo "=== 베이스 이미지 생성 완료 ==="
ls -lh "$BASE_IMAGE"
echo ""
echo "이제 vm-create.sh 를 실행할 수 있습니다."
