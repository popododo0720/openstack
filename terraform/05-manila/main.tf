# ===========================================
# Manila CephFS 공유
# ===========================================

# 공유 생성 (1GB)
resource "openstack_sharedfilesystem_share_v2" "test" {
  name        = "test-share"
  share_proto = "CEPHFS"
  size        = 1
  share_type  = "cephfs-type"
}

# 접근 권한 (ceph auth)
resource "openstack_sharedfilesystem_share_access_v2" "test" {
  share_id     = openstack_sharedfilesystem_share_v2.test.id
  access_type  = "cephx"
  access_to    = "test_user"
  access_level = "rw"
}
