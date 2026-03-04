output "lb_floating_ip" {
  description = "로드밸런서 Floating IP (브라우저에서 접속)"
  value       = openstack_networking_floatingip_v2.lb.address
}
output "lb_vip" {
  description = "LB 내부 VIP"
  value       = openstack_lb_loadbalancer_v2.web.vip_address
}
output "web_vm_ips" {
  description = "웹서버 내부 IP"
  value       = openstack_compute_instance_v2.web[*].access_ip_v4
}
