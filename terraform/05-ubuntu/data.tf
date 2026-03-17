# 01-base에서 만든 리소스 조회
data "openstack_networking_network_v2" "tenant" {
  name = "tenant-net"
}
data "openstack_networking_network_v2" "external" {
  name = "external-net"
}
data "openstack_networking_secgroup_v2" "test" {
  name = "test-secgroup"
}
