# ===========================================
# 웹서버 VM 2대 (간단한 HTTP 응답)
# ===========================================
resource "openstack_compute_instance_v2" "web" {
  count           = 2
  name            = "web-vm-${count.index + 1}"
  image_id        = data.openstack_images_image_v2.cirros.id
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  key_pair        = "test-keypair"
  security_groups = [data.openstack_networking_secgroup_v2.test.name]

  user_data = <<-USERDATA
    #!/bin/sh
    # 간단한 HTTP 서버 — hostname 응답
    while true; do
      echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$(hostname)" | nc -l -p 80
    done &
  USERDATA

  network {
    uuid = data.openstack_networking_network_v2.tenant.id
  }
}

# ===========================================
# Octavia 로드밸런서
# ===========================================
resource "openstack_lb_loadbalancer_v2" "web" {
  name          = "web-lb"
  vip_subnet_id = data.openstack_networking_subnet_v2.tenant.id
}

# HTTP 리스너 (80)
resource "openstack_lb_listener_v2" "http" {
  name            = "http-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.web.id
}

# 백엔드 풀 (ROUND_ROBIN)
resource "openstack_lb_pool_v2" "web" {
  name        = "web-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.http.id
}

# 멤버 등록 (웹서버 2대)
resource "openstack_lb_member_v2" "web" {
  count         = 2
  pool_id       = openstack_lb_pool_v2.web.id
  address       = openstack_compute_instance_v2.web[count.index].access_ip_v4
  protocol_port = 80
  subnet_id     = data.openstack_networking_subnet_v2.tenant.id
}

# 헬스체크
resource "openstack_lb_monitor_v2" "http" {
  name        = "http-monitor"
  pool_id     = openstack_lb_pool_v2.web.id
  type        = "HTTP"
  delay       = 5
  timeout     = 3
  max_retries = 3
  url_path    = "/"
}

# LB에 Floating IP 연결
resource "openstack_networking_floatingip_v2" "lb" {
  pool    = data.openstack_networking_network_v2.external.name
  port_id = openstack_lb_loadbalancer_v2.web.vip_port_id
}
