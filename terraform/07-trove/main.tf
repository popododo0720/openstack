# ===========================================
# Trove (DBaaS) — MySQL 인스턴스
# ===========================================
#
# 사전 준비 (openstack-deploy 에서 자동 처리):
# - 11-kolla-config.yml: 로컬 Docker registry + DB 이미지 미러링
# - 14-after-deploy.yml: 게스트 이미지 업로드 + 데이터스토어 등록
# ===========================================

resource "openstack_db_instance_v1" "mysql" {
  name      = "test-mysql"
  flavor_id = data.openstack_compute_flavor_v2.medium.id
  size        = 10
  volume_type = "__DEFAULT__"

  datastore {
    type    = "mysql"
    version = "8.0"
  }

  network {
    uuid = data.openstack_networking_network_v2.tenant.id
  }

  user {
    name      = "testuser"
    password  = "Test1234!"
    databases = ["testdb"]
  }

  database {
    name = "testdb"
  }

  timeouts {
    create = "30m"
  }
}
