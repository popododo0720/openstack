output "test_vm_floating_ip" {
  description = "테스트 VM Floating IP"
  value       = openstack_networking_floatingip_v2.test.address
}
output "test_vm_id" {
  value = openstack_compute_instance_v2.test.id
}
output "data_volume_id" {
  value = openstack_blockstorage_volume_v3.data.id
}
output "vol_boot_vm_id" {
  value = openstack_compute_instance_v2.vol_boot.id
}
