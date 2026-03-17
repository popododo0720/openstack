output "ubuntu_vm_id" {
  value = openstack_compute_instance_v2.ubuntu.id
}
output "ubuntu_vm_floating_ip" {
  description = "Ubuntu VM Floating IP"
  value       = openstack_networking_floatingip_v2.ubuntu.address
}
output "ubuntu_image_id" {
  value = openstack_images_image_v2.ubuntu.id
}
