output "external_network_id" {
  value = openstack_networking_network_v2.external.id
}
output "external_network_name" {
  value = openstack_networking_network_v2.external.name
}
output "tenant_network_id" {
  value = openstack_networking_network_v2.tenant.id
}
output "tenant_subnet_id" {
  value = openstack_networking_subnet_v2.tenant.id
}
output "router_id" {
  value = openstack_networking_router_v2.main.id
}
output "secgroup_name" {
  value = openstack_networking_secgroup_v2.test.name
}
output "image_id" {
  value = openstack_images_image_v2.cirros.id
}
output "flavor_small_id" {
  value = openstack_compute_flavor_v2.small.id
}
output "flavor_medium_id" {
  value = openstack_compute_flavor_v2.medium.id
}
output "keypair_name" {
  value = openstack_compute_keypair_v2.test.name
}
output "private_key" {
  value     = openstack_compute_keypair_v2.test.private_key
  sensitive = true
}
