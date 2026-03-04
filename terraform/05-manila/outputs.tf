output "share_id" {
  description = "Manila Share ID"
  value       = openstack_sharedfilesystem_share_v2.test.id
}
output "share_export" {
  description = "Manila Share 마운트 경로"
  value       = openstack_sharedfilesystem_share_v2.test.export_locations
}
output "access_key" {
  description = "CephX 접근 키"
  value       = openstack_sharedfilesystem_share_access_v2.test.access_key
  sensitive   = true
}
