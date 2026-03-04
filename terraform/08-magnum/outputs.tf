output "k8s_cluster_id" {
  description = "K8s 클러스터 ID"
  value       = openstack_containerinfra_cluster_v1.test.id
}
output "k8s_api_address" {
  description = "K8s API 주소"
  value       = openstack_containerinfra_cluster_v1.test.api_address
}
output "k8s_kubeconfig" {
  description = "kubeconfig 다운로드"
  value       = "openstack coe cluster config test-k8s"
}
