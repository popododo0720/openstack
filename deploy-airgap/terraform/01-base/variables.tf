variable "auth_url" {
  type = string
}
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "region" {
  type    = string
  default = "RegionOne"
}
variable "external_network_cidr" {
  type    = string
  default = "192.168.0.0/24"
}
variable "external_gateway" {
  type    = string
  default = "192.168.0.1"
}
variable "external_dns" {
  type    = list(string)
  default = ["8.8.8.8", "1.1.1.1"]
}
variable "external_allocation_pools" {
  type = list(object({
    start = string
    end   = string
  }))
  default = [
    {
      start = "192.168.0.24"
      end   = "192.168.0.29"
    },
    {
      start = "192.168.0.42"
      end   = "192.168.0.51"
    },
    {
      start = "192.168.0.53"
      end   = "192.168.0.57"
    },
  ]
}
variable "tenant_network_cidr" {
  type    = string
  default = "172.16.0.0/24"
}
variable "tenant_dns" {
  type    = list(string)
  default = ["8.8.8.8"]
}
