# ===========================================
# Magnum (K8s 클러스터)
# ===========================================
#
# 사전 준비:
# - before-test.sh 실행 (Fedora CoreOS 이미지 업로드)
# ===========================================

resource "openstack_containerinfra_clustertemplate_v1" "k8s" {
  name                  = "k8s-template"
  image                 = "fedora-coreos"
  coe                   = "kubernetes"
  flavor                = data.openstack_compute_flavor_v2.medium.name
  master_flavor         = data.openstack_compute_flavor_v2.medium.name
  dns_nameserver        = "8.8.8.8"
  docker_storage_driver = "overlay2"
  docker_volume_size    = 20
  volume_driver         = "cinder"
  network_driver        = "flannel"
  server_type           = "vm"
  external_network_id   = data.openstack_networking_network_v2.external.id
  floating_ip_enabled   = true
  master_lb_enabled     = false

  labels = {
    kube_tag               = "v1.30.14-rancher1"
    cloud_provider_enabled = "true"
  }
}

resource "openstack_containerinfra_cluster_v1" "test" {
  name                = "test-k8s"
  cluster_template_id = openstack_containerinfra_clustertemplate_v1.k8s.id
  master_count        = 1
  node_count          = 1
  keypair             = "test-keypair"
  create_timeout      = 60

  timeouts {
    create = "60m"
    delete = "30m"
  }
}
