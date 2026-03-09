# ===========================================
# Octavia Load Balancer (OVN provider)
# ===========================================
resource "openstack_lb_loadbalancer_v2" "test" {
  name          = "test-lb"
  vip_subnet_id = data.openstack_networking_subnet_v2.tenant.id
}

# ===========================================
# Listener (TCP:80) - OVN only supports TCP/UDP
# ===========================================
resource "openstack_lb_listener_v2" "tcp" {
  name            = "test-listener-tcp"
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.test.id
}

# ===========================================
# Pool (Round Robin, TCP)
# ===========================================
resource "openstack_lb_pool_v2" "tcp" {
  name        = "test-pool-tcp"
  protocol    = "TCP"
  lb_method   = "SOURCE_IP_PORT"
  listener_id = openstack_lb_listener_v2.tcp.id
}

# ===========================================
# Member (test-vm-1)
# ===========================================
resource "openstack_lb_member_v2" "test_vm" {
  pool_id       = openstack_lb_pool_v2.tcp.id
  address       = "172.16.0.234"
  protocol_port = 80
  subnet_id     = data.openstack_networking_subnet_v2.tenant.id
}

# ===========================================
# Health Monitor (TCP)
# ===========================================
resource "openstack_lb_monitor_v2" "tcp" {
  name        = "test-monitor-tcp"
  pool_id     = openstack_lb_pool_v2.tcp.id
  type        = "TCP"
  delay       = 10
  timeout     = 5
  max_retries = 3
}

# ===========================================
# Floating IP for LB VIP
# ===========================================
resource "openstack_networking_floatingip_v2" "lb" {
  pool    = data.openstack_networking_network_v2.external.name
  port_id = openstack_lb_loadbalancer_v2.test.vip_port_id
}
