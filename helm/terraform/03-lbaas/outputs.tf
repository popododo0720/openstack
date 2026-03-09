output "lb_id" {
  value = openstack_lb_loadbalancer_v2.test.id
}
output "lb_vip" {
  value = openstack_lb_loadbalancer_v2.test.vip_address
}
output "lb_floating_ip" {
  value = openstack_networking_floatingip_v2.lb.address
}
output "listener_id" {
  value = openstack_lb_listener_v2.tcp.id
}
output "pool_id" {
  value = openstack_lb_pool_v2.tcp.id
}
