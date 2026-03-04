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
