provider "openstack" {
  auth_url      = var.auth_url
  user_name     = var.admin_user
  password      = var.admin_password
  tenant_name   = "admin"
  domain_name   = "Default"
  region        = var.region
  endpoint_type = "internal"
  insecure      = true
}
