# ===========================================
# 테스트 VM (이미지 부팅)
# ===========================================
resource "openstack_compute_instance_v2" "test" {
  name            = "test-vm-1"
  image_id        = data.openstack_images_image_v2.cirros.id
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  key_pair        = "test-keypair"
  security_groups = [data.openstack_networking_secgroup_v2.test.name]

  network {
    uuid = data.openstack_networking_network_v2.tenant.id
  }
}

# ===========================================
# Floating IP → VM
# ===========================================
data "openstack_networking_port_v2" "test" {
  device_id  = openstack_compute_instance_v2.test.id
  network_id = openstack_compute_instance_v2.test.network.0.uuid
}

resource "openstack_networking_floatingip_v2" "test" {
  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_networking_floatingip_associate_v2" "test" {
  floating_ip = openstack_networking_floatingip_v2.test.address
  port_id     = data.openstack_networking_port_v2.test.id
}

# ===========================================
# 추가 데이터 볼륨 → VM에 attach
# ===========================================
resource "openstack_blockstorage_volume_v3" "data" {
  name        = "data-vol-1"
  size        = 10
  description = "test-vm-1 데이터 볼륨"
}

resource "openstack_compute_volume_attach_v2" "data" {
  instance_id = openstack_compute_instance_v2.test.id
  volume_id   = openstack_blockstorage_volume_v3.data.id
}

# ===========================================
# 볼륨 부팅 VM (이미지→볼륨→부팅)
# ===========================================
resource "openstack_blockstorage_volume_v3" "boot" {
  name     = "boot-vol-1"
  size     = 5
  image_id = data.openstack_images_image_v2.cirros.id
}

resource "openstack_compute_instance_v2" "vol_boot" {
  name            = "vol-boot-vm-1"
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  key_pair        = "test-keypair"
  security_groups = [data.openstack_networking_secgroup_v2.test.name]

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.boot.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = data.openstack_networking_network_v2.tenant.id
  }
}
