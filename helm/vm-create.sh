#!/bin/bash
# helm1 VM 생성 스크립트 (OpenStack-Helm 싱글노드 테스트용)
# 기존 stack1/2/3 통합 사양: 24 vCPU / 48GB RAM / 100GB 디스크 + 150GB OSD
# NIC 6개: management + internal + storage + external(OVS) + provider-mgmt(OVS) + external-access

IMAGE_DIR="/DATA/libvirt/images"
BASE_IMAGE="${IMAGE_DIR}/ubuntu-base.qcow2"
DISK_SIZE="100G"
OSD_SIZE="150G"
SWAP_SIZE="16G"
RAM_MB="49152"
VCPUS="24"

VM="helm1"
MGMT_IP="10.250.254.21"
INT_IP="10.0.2.121"
STOR_IP="192.168.73.21"
EXT_ACC_IP="192.168.0.61"

# 네트워크 설정
MGMT_GW="10.250.254.1"
MGMT_PREFIX="24"
INTERNAL_PREFIX="24"
STORAGE_PREFIX="24"
EXTERNAL_PREFIX="24"
DNS_SERVER="8.8.8.8"

# root 비밀번호
ROOT_PASSWORD="root"

# SSH 공개키 (있으면 사용)
SSH_PUBKEY=""
if [ -f /root/.ssh/id_rsa.pub ]; then
    SSH_PUBKEY=$(cat /root/.ssh/id_rsa.pub)
fi

# 베이스 이미지 확인
if [ ! -f "$BASE_IMAGE" ]; then
    echo "에러: 베이스 이미지가 없습니다: $BASE_IMAGE"
    echo ""
    echo "베이스 이미지 생성 방법:"
    echo "  wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    echo "  mv noble-server-cloudimg-amd64.img $BASE_IMAGE"
    exit 1
fi

# cloud-init ISO 생성
create_cloud_init_iso() {
    local ISO_DIR="/tmp/cloud-init-${VM}"
    local ISO_FILE="${IMAGE_DIR}/${VM}-cidata.iso"

    mkdir -p "$ISO_DIR"

    cat > "${ISO_DIR}/meta-data" << EOF
instance-id: ${VM}
local-hostname: ${VM}
EOF

    cat > "${ISO_DIR}/user-data" << EOF
#cloud-config
hostname: ${VM}
fqdn: ${VM}
manage_etc_hosts: true

users:
  - name: root
    lock_passwd: false
    hashed_passwd: $(openssl passwd -6 "$ROOT_PASSWORD")
    shell: /bin/bash
EOF

    if [ -n "$SSH_PUBKEY" ]; then
        cat >> "${ISO_DIR}/user-data" << EOF
    ssh_authorized_keys:
      - ${SSH_PUBKEY}
EOF
    fi

    cat >> "${ISO_DIR}/user-data" << EOF

ssh_pwauth: true
disable_root: false

# 네트워크 설정 (netplan)
# enp1s0: management (ansible/SSH, 인터넷, default gw)
# enp2s0: internal/API (K8s internal)
# enp3s0: storage (Ceph/Rook internal)
# enp4s0: external (IP 없음, Neutron br-ex provider)
# enp5s0: provider-mgmt (IP 없음, 예비)
# enp6s0: external access (192.168.0.x 고정IP)
write_files:
  - path: /etc/netplan/50-cloud-init.yaml
    content: |
      network:
        version: 2
        ethernets:
          enp1s0:
            addresses:
              - ${MGMT_IP}/${MGMT_PREFIX}
            routes:
              - to: default
                via: ${MGMT_GW}
            nameservers:
              addresses:
                - ${DNS_SERVER}
          enp2s0:
            addresses:
              - ${INT_IP}/${INTERNAL_PREFIX}
          enp3s0:
            addresses:
              - ${STOR_IP}/${STORAGE_PREFIX}
          enp4s0:
            dhcp4: false
          enp5s0:
            dhcp4: false
          enp6s0:
            addresses:
              - ${EXT_ACC_IP}/${EXTERNAL_PREFIX}

  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter
      nbd

  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward = 1

runcmd:
  - fallocate -l ${SWAP_SIZE} /swapfile
  - chmod 600 /swapfile
  - mkswap /swapfile
  - swapon /swapfile
  - echo "/swapfile none swap sw 0 0" >> /etc/fstab
  - netplan apply
  - systemctl restart systemd-resolved
  - modprobe overlay
  - modprobe br_netfilter
  - modprobe nbd
  - sysctl --system

bootcmd:
  - echo "${MGMT_IP} ${VM}" >> /etc/hosts
EOF

    genisoimage -output "$ISO_FILE" -volid cidata -joliet -rock \
        "${ISO_DIR}/user-data" "${ISO_DIR}/meta-data" 2>/dev/null \
        || mkisofs -output "$ISO_FILE" -volid cidata -joliet -rock \
        "${ISO_DIR}/user-data" "${ISO_DIR}/meta-data" 2>/dev/null \
        || cloud-localds "$ISO_FILE" "${ISO_DIR}/user-data" "${ISO_DIR}/meta-data"

    rm -rf "$ISO_DIR"
    echo "$ISO_FILE"
}

echo "=== ${VM} VM 생성 시작 ==="
echo "사양: ${VCPUS} vCPU / $((RAM_MB/1024)) GB RAM / ${DISK_SIZE} 디스크 + ${OSD_SIZE} OSD"
echo "NIC 구성:"
echo "  enp1s0: management  (${MGMT_IP}, 인터넷+SSH)"
echo "  enp2s0: internal    (${INT_IP}, K8s 내부)"
echo "  enp3s0: storage     (${STOR_IP}, Ceph/Rook)"
echo "  enp4s0: external    (IP없음, Neutron br-ex)"
echo "  enp5s0: provider    (IP없음, 예비)"
echo "  enp6s0: ext-access  (${EXT_ACC_IP}, 호스트 고정IP)"
echo ""

if virsh list --all --name | grep -q "^${VM}$"; then
    echo "이미 존재함. 삭제하려면: virsh destroy ${VM}; virsh undefine ${VM} --remove-all-storage"
    exit 1
fi

echo "  - 메인 디스크 생성 (${DISK_SIZE})..."
cp "$BASE_IMAGE" "${IMAGE_DIR}/${VM}.qcow2"
qemu-img resize "${IMAGE_DIR}/${VM}.qcow2" $DISK_SIZE 2>/dev/null

echo "  - OSD 디스크 생성 (${OSD_SIZE})..."
qemu-img create -f qcow2 "${IMAGE_DIR}/${VM}-osd.qcow2" $OSD_SIZE

echo "  - cloud-init ISO 생성..."
CIDATA_ISO=$(create_cloud_init_iso)

echo "  - VM 정의 중..."
virt-install \
    --name $VM \
    --ram $RAM_MB \
    --vcpus $VCPUS \
    --cpu host-passthrough \
    --os-variant ubuntu24.04 \
    --disk path="${IMAGE_DIR}/${VM}.qcow2",format=qcow2,bus=virtio \
    --disk path="${IMAGE_DIR}/${VM}-osd.qcow2",format=qcow2,bus=virtio \
    --disk path="${CIDATA_ISO}",device=cdrom \
    --network network=management,model=virtio \
    --network network=internal,model=virtio \
    --network network=storage,model=virtio \
    --network bridge=br0,model=virtio \
    --network network=internal,model=virtio \
    --network bridge=br0,model=virtio \
    --graphics vnc,listen=0.0.0.0 \
    --noautoconsole \
    --import \
    --boot hd

echo ""
echo "=== ${VM} 생성 완료 ==="
virsh list --all

echo ""
echo "사양: ${VCPUS} vCPU / $((RAM_MB/1024)) GB RAM"
echo "디스크: ${DISK_SIZE} (메인) + ${OSD_SIZE} (Ceph OSD)"
echo ""
echo "NIC 구성:"
echo "  enp1s0: ${MGMT_IP}  (management, SSH, 인터넷)"
echo "  enp2s0: ${INT_IP}   (internal, K8s)"
echo "  enp3s0: ${STOR_IP}  (storage, Ceph)"
echo "  enp4s0: IP없음      (Neutron br-ex, provider)"
echo "  enp5s0: IP없음      (예비)"
echo "  enp6s0: ${EXT_ACC_IP} (external 고정IP)"
echo ""
echo "SSH 접속:"
echo "  ssh root@${MGMT_IP}  # management"
echo "  ssh root@${EXT_ACC_IP}  # external"
