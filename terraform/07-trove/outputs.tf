output "mysql_id" {
  description = "Trove MySQL 인스턴스 ID"
  value       = openstack_db_instance_v1.mysql.id
}
output "mysql_addresses" {
  description = "MySQL 접속 주소"
  value       = openstack_db_instance_v1.mysql.addresses
}
