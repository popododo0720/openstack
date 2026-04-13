#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/inventory.ini"
ROOT_PASS="root"

HOSTS=()
NAMES=()
MANAGEMENT_IPS=()
STORAGE_IPS=()
INTERNAL_IPS=()
TUNNEL_IPS=()
EXTERNAL_IPS=()

extract_value() {
    local key="$1"
    local line="$2"
    echo "$line" | tr ' ' '\n' | awk -F= -v k="$key" '$1 == k {print $2}'
}

extract_cidr_suffix() {
    local key="$1"
    local value
    value=$(awk -F= -v k="$key" '$1 == k {print $2}' "$INVENTORY_FILE")
    if [ -n "$value" ] && [[ "$value" == */* ]]; then
        echo "/${value##*/}"
    else
        echo "/24"
    fi
}

while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# || "$line" =~ ^\[ ]] && continue
    [[ "$line" != stack* ]] && continue

    NAMES+=("$(echo "$line" | awk '{print $1}')")
    HOSTS+=("$(extract_value ansible_host "$line")")
    MANAGEMENT_IPS+=("$(extract_value ansible_host "$line")")
    STORAGE_IPS+=("$(extract_value storage_ip "$line")")
    INTERNAL_IPS+=("$(extract_value internal_ip "$line")")
    TUNNEL_IPS+=("$(extract_value tunnel_ip "$line")")
    EXTERNAL_IPS+=("$(extract_value external_ip "$line")")
done < "$INVENTORY_FILE"

MANAGEMENT_IF="eno2np1"
EXTERNAL_IF="enp216s0f0"
NEUTRON_EXTERNAL_IF="$(awk -F= '$1 == "neutron_external_interface" {print $2}' "$INVENTORY_FILE")"
TUNNEL_IF="enp216s0f2"
INTERNAL_IF="$(awk -F= '$1 == "network_interface" {print $2}' "$INVENTORY_FILE")"
STORAGE_IF="$(awk -F= '$1 == "storage_interface" {print $2}' "$INVENTORY_FILE")"
EXTERNAL_GATEWAY="$(awk -F= '$1 == "external_network" {split($2, a, "."); print a[1] "." a[2] "." a[3] ".1"}' "$INVENTORY_FILE")"
DNS_SERVERS="[1.1.1.1,8.8.8.8]"

MANAGEMENT_CIDR="$(extract_cidr_suffix management_network)"
STORAGE_CIDR="$(extract_cidr_suffix storage_network)"
INTERNAL_CIDR="$(extract_cidr_suffix internal_network)"
TUNNEL_CIDR="$(extract_cidr_suffix tunnel_network)"
EXTERNAL_CIDR="$(extract_cidr_suffix external_network)"

OSD_DEVICES_RAW="$(awk -F= '$1 == "osd_devices" {print $2}' "$INVENTORY_FILE")"
IFS=',' read -r -a OSD_DEVICES <<< "$OSD_DEVICES_RAW"

if [ ! -f /root/.ssh/id_rsa ]; then
    echo "[1/5] SSH 키 생성..."
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -q
else
    echo "[1/5] SSH 키 이미 존재"
fi

echo "[2/5] SSH 키 배포 (관리 네트워크)..."
for i in "${!HOSTS[@]}"; do
    host=${HOSTS[$i]}
    name=${NAMES[$i]}
    ssh-keygen -f /root/.ssh/known_hosts -R "$host" 2>/dev/null || true
    echo "  → $name ($host)"
    sshpass -p "$ROOT_PASS" ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@"$host"
done

echo "[3/5] SSH 연결 테스트..."
for i in "${!HOSTS[@]}"; do
    host=${HOSTS[$i]}
    name=${NAMES[$i]}
    result=$(ssh -o StrictHostKeyChecking=no root@"$host" "hostname" 2>/dev/null)
    if [ "$result" = "$name" ]; then
        echo "  ✓ $name ($host) OK"
    else
        echo "  ✗ $name ($host) FAILED"
        exit 1
    fi
done

echo "[4/5] OSD 디스크 초기화 (Ceph용)..."
for i in "${!HOSTS[@]}"; do
    host=${HOSTS[$i]}
    name=${NAMES[$i]}
    for dev in "${OSD_DEVICES[@]}"; do
        echo "  → $name ($host) $dev 초기화"
        ssh -o StrictHostKeyChecking=no root@"$host" "dmsetup remove_all 2>/dev/null; vgremove -f \$(vgs --noheadings -o vg_name 2>/dev/null | grep ceph) 2>/dev/null; wipefs -af $dev; sgdisk --zap-all $dev; dd if=/dev/zero of=$dev bs=1M count=100 2>/dev/null; partprobe $dev; echo done"
        echo "    OK"
    done
done

echo "[5/5] 운영 네트워크 netplan 설정..."
for i in "${!HOSTS[@]}"; do
    host=${HOSTS[$i]}
    name=${NAMES[$i]}
    management_ip=${MANAGEMENT_IPS[$i]}
    storage_ip=${STORAGE_IPS[$i]}
    internal_ip=${INTERNAL_IPS[$i]}
    tunnel_ip=${TUNNEL_IPS[$i]}
    external_ip=${EXTERNAL_IPS[$i]}

    echo "  → $name ($host) cloud-init netplan 덮어쓰기"
    ssh -o StrictHostKeyChecking=no root@"$host" "cat > /etc/netplan/50-cloud-init.yaml <<NETPLAN
network:
  version: 2
  renderer: networkd
  ethernets:
    ${MANAGEMENT_IF}:
      dhcp4: false
      dhcp6: false
      addresses:
        - ${management_ip}${MANAGEMENT_CIDR}
    ${EXTERNAL_IF}:
      dhcp4: false
      dhcp6: false
      addresses:
        - ${external_ip}${EXTERNAL_CIDR}
      routes:
        - to: default
          via: ${EXTERNAL_GATEWAY}
      nameservers:
        addresses: ${DNS_SERVERS}
    ${NEUTRON_EXTERNAL_IF}:
      dhcp4: false
      dhcp6: false
    ${TUNNEL_IF}:
      dhcp4: false
      dhcp6: false
      addresses:
        - ${tunnel_ip}${TUNNEL_CIDR}
    ${INTERNAL_IF}:
      dhcp4: false
      dhcp6: false
      addresses:
        - ${internal_ip}${INTERNAL_CIDR}
    ${STORAGE_IF}:
      dhcp4: false
      dhcp6: false
      addresses:
        - ${storage_ip}${STORAGE_CIDR}
NETPLAN
netplan generate
netplan apply"
    echo "    OK"
done

echo ""
echo "완료."
