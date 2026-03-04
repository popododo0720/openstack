# 01-base에서 만든 리소스를 이름으로 조회
data "openstack_networking_network_v2" "external" {
  name = "external-net"
}
data "openstack_networking_network_v2" "tenant" {
  name = "tenant-net"
}
data "openstack_networking_subnet_v2" "tenant" {
  name = "tenant-subnet"
}
data "openstack_networking_secgroup_v2" "test" {
  name = "test-secgroup"
}
data "openstack_images_image_v2" "cirros" {
  name        = "cirros-0.6.3"
  most_recent = true
}
data "openstack_compute_flavor_v2" "small" {
  name = "m1.small"
}
data "openstack_compute_flavor_v2" "medium" {
  name = "m1.medium"
}
