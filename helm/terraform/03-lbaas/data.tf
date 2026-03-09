data "openstack_networking_subnet_v2" "tenant" {
  name = "tenant-subnet"
}

data "openstack_networking_network_v2" "external" {
  name = "external-net"
}
