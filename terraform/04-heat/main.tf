# ===========================================
# Heat Stack 배포
# ===========================================
resource "openstack_orchestration_stack_v1" "test" {
  name = "heat-test-stack"

  template_opts = {
    Bin = file("${path.module}/template.yaml")
  }

  environment_opts = {
    Bin = "\n"
  }

  parameters = {
    image    = "cirros-0.6.3"
    flavor   = "m1.small"
    network  = "tenant-net"
    key_name = "test-keypair"
  }

  disable_rollback = true
  timeout          = 30
}
