#!/bin/bash
# VM 3개 생성 스크립트 (cloud-init 포함)
# NIC 6개: management + internal + storage + external(OVS,IP없음) + provider-mgmt(OVS,IP없음) + external-access(고정IP)
# 사전 조건: /DATA/libvirt/images/ubuntu-base.qcow2 (cloud-init 지원 Ubuntu 이미지)

IMAGE_DIR="/DATA/libvirt/images"
BASE_IMAGE="${IMAGE_DIR}/ubuntu-base.qcow2"
DISK_SIZE="80G"
OSD_SIZE="20G"
SWAP_SIZE="16G"
RAM_MB="16384"
VCPUS="8"

# VM 설정 (이름, management IP, internal IP, storage IP, external access IP)
declare -A VM_CONFIG
VM_CONFIG[stack1]="10.250.254.11 10.0.2.111 192.168.73.11 192.168.0.61"
VM_CONFIG[stack2]="10.250.254.12 10.0.2.112 192.168.73.12 192.168.0.62"
VM_CONFIG[stack3]="10.250.254.13 10.0.2.113 192.168.73.13 192.168.0.63"

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

# cloud-init ISO 생성 함수
create_cloud_init_iso() {
    local VM=$1
    local MGMT_IP=$2
    local INT_IP=$3
    local STOR_IP=$4
    local EXT_ACC_IP=$5
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
# enp2s0: internal/API (kolla network_interface, VIP .110)
# enp3s0: storage (Ceph)
# enp4s0: external (IP 없음, OVS br-ex → physnet1)
# enp5s0: provider-mgmt (IP 없음, OVS br-mgmt → physnet2)
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

runcmd:
  - fallocate -l ${SWAP_SIZE} /swapfile
  - chmod 600 /swapfile
  - mkswap /swapfile
  - swapon /swapfile
  - echo "/swapfile none swap sw 0 0" >> /etc/fstab
  - netplan apply
  - systemctl restart systemd-resolved

bootcmd:
  - echo "192.168.73.11 stack1" >> /etc/hosts
  - echo "192.168.73.12 stack2" >> /etc/hosts
  - echo "192.168.73.13 stack3" >> /etc/hosts
  - echo "10.0.2.111 stack1-internal" >> /etc/hosts
  - echo "10.0.2.112 stack2-internal" >> /etc/hosts
  - echo "10.0.2.113 stack3-internal" >> /etc/hosts
EOF

    genisoimage -output "$ISO_FILE" -volid cidata -joliet -rock \
        "${ISO_DIR}/user-data" "${ISO_DIR}/meta-data" 2>/dev/null \
        || mkisofs -output "$ISO_FILE" -volid cidata -joliet -rock \
        "${ISO_DIR}/user-data" "${ISO_DIR}/meta-data" 2>/dev/null \
        || cloud-localds "$ISO_FILE" "${ISO_DIR}/user-data" "${ISO_DIR}/meta-data"

    rm -rf "$ISO_DIR"
    echo "$ISO_FILE"
}

echo "=== VM 생성 시작 ==="
echo "NIC 구성:"
echo "  enp1s0: management  (10.250.254.x, 인터넷+ansible)"
echo "  enp2s0: internal    (10.0.2.x, kolla API, VIP .110)"
echo "  enp3s0: storage     (192.168.73.x, Ceph)"
echo "  enp4s0: external    (IP없음, OVS br-ex)"
echo "  enp5s0: provider    (IP없음, OVS br-mgmt)"
echo "  enp6s0: ext-access  (192.168.0.x, 호스트 고정IP)"
echo ""

for VM in stack1 stack2 stack3; do
    IPS=(${VM_CONFIG[$VM]})
    MGMT_IP=${IPS[0]}
    INT_IP=${IPS[1]}
    STOR_IP=${IPS[2]}
    EXT_ACC_IP=${IPS[3]}

    echo "[$VM] 생성 중... (Mgmt: $MGMT_IP, Internal: $INT_IP, Storage: $STOR_IP, ExtAccess: $EXT_ACC_IP)"

    if virsh list --all --name | grep -q "^${VM}$"; then
        echo "  - 이미 존재함, 스킵"
        continue
    fi

    echo "  - 메인 디스크 생성..."
    cp "$BASE_IMAGE" "${IMAGE_DIR}/${VM}.qcow2"
    qemu-img resize "${IMAGE_DIR}/${VM}.qcow2" $DISK_SIZE 2>/dev/null

    echo "  - OSD 디스크 생성..."
    qemu-img create -f qcow2 "${IMAGE_DIR}/${VM}-osd.qcow2" $OSD_SIZE

    echo "  - cloud-init ISO 생성..."
    CIDATA_ISO=$(create_cloud_init_iso "$VM" "$MGMT_IP" "$INT_IP" "$STOR_IP" "$EXT_ACC_IP")

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

    echo "[$VM] 생성 완료"
done

echo ""
echo "=== 모든 VM 생성 완료 ==="
virsh list --all

echo ""
echo "NIC 구성:"
echo "  enp1s0: 10.250.254.11/12/13 (management, ansible, 인터넷)"
echo "  enp2s0: 10.0.2.111/112/113  (internal/API, VIP .110)"
echo "  enp3s0: 192.168.73.11/12/13 (Ceph storage)"
echo "  enp4s0: IP없음              (OVS br-ex, external VIP .60)"
echo "  enp5s0: IP없음              (OVS br-mgmt, provider physnet2)"
echo "  enp6s0: 192.168.0.61/62/63  (external 고정IP)"
echo ""
echo "SSH 접속:"
echo "  ssh root@10.250.254.11  # stack1"
echo "  ssh root@10.250.254.12  # stack2"
echo "  ssh root@10.250.254.13  # stack3"
