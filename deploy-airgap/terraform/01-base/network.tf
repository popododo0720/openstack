# ===========================================
# Provider/External Network only (no tenant overlay network)
# ===========================================
resource "openstack_networking_network_v2" "external" {
  name           = "external-net"
  admin_state_up = true
  shared         = true
  external       = true
  segments {
    network_type     = "flat"
    physical_network = "external"
  }
}

resource "openstack_networking_subnet_v2" "external" {
  name            = "external-subnet"
  network_id      = openstack_networking_network_v2.external.id
  cidr            = var.external_network_cidr
  gateway_ip      = var.external_gateway
  dns_nameservers = var.external_dns
  enable_dhcp     = true
  dynamic "allocation_pool" {
    for_each = var.external_allocation_pools
    content {
      start = allocation_pool.value.start
      end   = allocation_pool.value.end
    }
  }
}
