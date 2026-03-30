# Provider-only scenario resources lookup
data "openstack_networking_network_v2" "external" {
  name = "external-net"
}
data "openstack_networking_secgroup_v2" "test" {
  name = "test-secgroup"
}
