# ===========================================
# 이미지 (cirros)
# ===========================================
resource "openstack_images_image_v2" "cirros" {
  name             = "cirros-0.6.3"
  image_source_url = "https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type = "linux"
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
# 클라우드 이미지
# ===========================================
resource "openstack_images_image_v2" "ubuntu" {
  name             = "ubuntu-24.04"
  image_source_url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type    = "linux"
    os_distro  = "ubuntu"
    os_version = "24.04"
  }
}

resource "openstack_images_image_v2" "rocky" {
  name             = "rocky-9"
  image_source_url = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type    = "linux"
    os_distro  = "rocky"
    os_version = "9"
  }
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
