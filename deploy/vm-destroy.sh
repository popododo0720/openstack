#!/bin/bash
# VM 3개 삭제 스크립트

VMS="stack1 stack2 stack3"
IMAGE_DIR="/DATA/libvirt/images"

echo "=== VM 삭제 시작 ==="

for VM in $VMS; do
    echo "[$VM] 처리 중..."

    # VM 실행 중이면 종료
    if virsh list --name | grep -q "^${VM}$"; then
        echo "  - VM 종료 중..."
        virsh destroy $VM 2>/dev/null
    fi

    # VM 정의 삭제
    if virsh list --all --name | grep -q "^${VM}$"; then
        echo "  - VM 정의 삭제..."
        virsh undefine $VM --remove-all-storage 2>/dev/null || virsh undefine $VM 2>/dev/null
    fi

    # 디스크 파일 삭제 (혹시 남아있으면)
    for DISK in "${IMAGE_DIR}/${VM}.qcow2" "${IMAGE_DIR}/${VM}-osd.qcow2" "${IMAGE_DIR}/${VM}-cidata.iso"; do
        if [ -f "$DISK" ]; then
            echo "  - 파일 삭제: $DISK"
            rm -f "$DISK"
        fi
    done

    echo "[$VM] 완료"
done

echo "=== 모든 VM 삭제 완료 ==="
virsh list --all
