# ===========================================
# 로컬 이미지 등록
# inventory.ini 기준 환경과 맞춰 외부 다운로드 없이
# terraform/images 아래 파일만 Glance에 등록한다.
# ===========================================
resource "openstack_images_image_v2" "cirros" {
  name             = "cirros-0.6.3"
  local_file_path  = "${path.module}/../images/cirros-0.6.3-x86_64-disk.img"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type       = "linux"
    os_admin_user = "cirros"
  }
}

resource "openstack_images_image_v2" "ubuntu" {
  name             = "ubuntu-24.04"
  local_file_path  = "${path.module}/../images/ubuntu-24.04-noble-amd64.img"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type       = "linux"
    os_distro     = "ubuntu"
    os_version    = "24.04"
    os_admin_user = "ubuntu"
  }
}

resource "openstack_images_image_v2" "debian" {
  name             = "debian-12"
  local_file_path  = "${path.module}/../images/debian-12-bookworm-genericcloud-amd64.qcow2"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type       = "linux"
    os_distro     = "debian"
    os_version    = "12"
    os_admin_user = "debian"
  }
}

resource "openstack_images_image_v2" "rocky" {
  name             = "rocky-9"
  local_file_path  = "${path.module}/../images/rocky-9-genericcloud-base.qcow2"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type       = "linux"
    os_distro     = "rocky"
    os_version    = "9"
    os_admin_user = "cloud-user"
  }
}

resource "openstack_images_image_v2" "centos_stream" {
  name             = "centos-stream-9"
  local_file_path  = "${path.module}/../images/centos-stream-9-genericcloud.qcow2"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type       = "linux"
    os_distro     = "centos"
    os_version    = "9-stream"
    os_admin_user = "cloud-user"
  }
}

resource "openstack_images_image_v2" "alpine" {
  name             = "alpine-3.19.8"
  local_file_path  = "${path.module}/../images/alpine-3.19.8-nocloud-cloudinit.qcow2"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type    = "linux"
    os_distro  = "alpine"
    os_version = "3.19.8"
  }
}

# Talos는 raw.zst 압축본이 아니라 압축 해제된 raw 파일을 사용한다.
resource "openstack_images_image_v2" "talos" {
  name             = "talos-metal-amd64"
  local_file_path  = "${path.module}/../images/talos-metal-amd64.raw"
  container_format = "bare"
  disk_format      = "raw"
  visibility       = "public"
  properties = {
    os_type    = "linux"
    os_distro  = "talos"
    os_version = "latest"
  }
}

# ===========================================
# 플레이버
# ===========================================
resource "openstack_compute_flavor_v2" "small" {
  name      = "m1.small"
  ram       = 512
  vcpus     = 1
  disk      = 5
  is_public = true
}

resource "openstack_compute_flavor_v2" "medium" {
  name      = "m1.medium"
  ram       = 1024
  vcpus     = 1
  disk      = 10
  is_public = true
}

# ===========================================
# SSH 키페어
# ===========================================
resource "openstack_compute_keypair_v2" "test" {
  name = "test-keypair"
}

# ===========================================
# VM용 플레이버 (Alloy 포함)
# ===========================================
resource "openstack_compute_flavor_v2" "large" {
  name      = "m1.large"
  ram       = 2048
  vcpus     = 2
  disk      = 20
  is_public = true
}
