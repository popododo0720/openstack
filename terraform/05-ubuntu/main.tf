# ===========================================
# Ubuntu 24.04 클라우드 이미지
# ===========================================
resource "openstack_images_image_v2" "ubuntu" {
  name             = "ubuntu-24.04"
  image_source_url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  properties = {
    os_type     = "linux"
    os_distro   = "ubuntu"
    os_version  = "24.04"
    hw_scsi_model = "virtio-scsi"
  }
}

# ===========================================
# Ubuntu용 플레이버 (2vCPU, 2GB RAM, 20GB disk)
# ===========================================
resource "openstack_compute_flavor_v2" "ubuntu" {
  name      = "m1.ubuntu"
  ram       = 2048
  vcpus     = 2
  disk      = 20
  is_public = true
}

# ===========================================
# 볼륨 부팅 (Ubuntu)
# ===========================================
resource "openstack_blockstorage_volume_v3" "ubuntu_boot" {
  name     = "ubuntu-boot-vol"
  size     = 20
  image_id = openstack_images_image_v2.ubuntu.id
}

# ===========================================
# Ubuntu VM (볼륨 부팅)
# ===========================================
resource "openstack_compute_instance_v2" "ubuntu" {
  name            = "ubuntu-vm-1"
  flavor_id       = openstack_compute_flavor_v2.ubuntu.id
  key_pair        = "test-keypair"
  security_groups = [data.openstack_networking_secgroup_v2.test.name]

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.ubuntu_boot.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = data.openstack_networking_network_v2.tenant.id
  }
}

# ===========================================
# Floating IP → Ubuntu VM
# ===========================================
data "openstack_networking_port_v2" "ubuntu" {
  device_id  = openstack_compute_instance_v2.ubuntu.id
  network_id = openstack_compute_instance_v2.ubuntu.network.0.uuid
}

resource "openstack_networking_floatingip_v2" "ubuntu" {
  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_networking_floatingip_associate_v2" "ubuntu" {
  floating_ip = openstack_networking_floatingip_v2.ubuntu.address
  port_id     = data.openstack_networking_port_v2.ubuntu.id
}
