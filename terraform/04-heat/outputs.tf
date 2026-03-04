output "stack_id" {
  description = "Heat Stack ID"
  value       = openstack_orchestration_stack_v1.test.id
}
output "stack_status" {
  description = "Heat Stack 상태"
  value       = openstack_orchestration_stack_v1.test.status
}
output "stack_outputs" {
  description = "Heat Stack 출력값"
  value       = openstack_orchestration_stack_v1.test.outputs
}
