#!/bin/bash
# helm1 VM 삭제 스크립트

IMAGE_DIR="/DATA/libvirt/images"
VM="helm1"

echo "=== ${VM} VM 삭제 ==="

if ! virsh list --all --name | grep -q "^${VM}$"; then
    echo "${VM} VM이 존재하지 않습니다."
    exit 0
fi

echo "  - VM 중지..."
virsh destroy ${VM} 2>/dev/null

echo "  - VM 정의 해제 + 디스크 삭제..."
virsh undefine ${VM} --remove-all-storage 2>/dev/null

# cloud-init ISO 수동 정리 (undefine이 못 지울 수 있음)
rm -f "${IMAGE_DIR}/${VM}-cidata.iso"
rm -f "${IMAGE_DIR}/${VM}.qcow2"
rm -f "${IMAGE_DIR}/${VM}-osd.qcow2"

echo ""
echo "=== ${VM} 삭제 완료 ==="
virsh list --all
