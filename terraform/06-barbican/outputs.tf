output "password_secret_ref" {
  description = "패스워드 시크릿 참조 URL"
  value       = openstack_keymanager_secret_v1.password.secret_ref
}
output "aes_key_secret_ref" {
  description = "AES 키 시크릿 참조 URL"
  value       = openstack_keymanager_secret_v1.symmetric_key.secret_ref
}
output "container_ref" {
  description = "시크릿 컨테이너 참조 URL"
  value       = openstack_keymanager_container_v1.test.container_ref
}
