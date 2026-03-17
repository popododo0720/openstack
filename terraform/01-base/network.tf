# ===========================================
# Provider Network (외부)
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
  enable_dhcp     = false
  allocation_pool {
    start = "192.168.0.24"
    end   = "192.168.0.29"
  }
  allocation_pool {
    start = "192.168.0.42"
    end   = "192.168.0.51"
  }
  allocation_pool {
    start = "192.168.0.53"
    end   = "192.168.0.57"
  }
}

# ===========================================
# Tenant Network (내부 VXLAN)
# ===========================================
resource "openstack_networking_network_v2" "tenant" {
  name           = "tenant-net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "tenant" {
  name            = "tenant-subnet"
  network_id      = openstack_networking_network_v2.tenant.id
  cidr            = var.tenant_network_cidr
  dns_nameservers = var.tenant_dns
  enable_dhcp     = true
}

# ===========================================
# Router (내부 <-> 외부)
# ===========================================
resource "openstack_networking_router_v2" "main" {
  name                = "main-router"
  admin_state_up      = true
  external_network_id = openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "tenant" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.tenant.id
}
