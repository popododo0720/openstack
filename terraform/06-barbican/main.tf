# ===========================================
# Barbican 시크릿 저장
# ===========================================

# 일반 시크릿 (패스워드)
resource "openstack_keymanager_secret_v1" "password" {
  name                 = "test-db-password"
  payload              = "SuperSecretPassword123!"
  payload_content_type = "text/plain"
  secret_type          = "passphrase"
}

# 대칭키 (AES)
resource "openstack_keymanager_secret_v1" "symmetric_key" {
  name                     = "test-aes-key"
  payload                  = "dGhpcyBpcyBhIHRlc3Qga2V5"
  payload_content_type     = "application/octet-stream"
  payload_content_encoding = "base64"
  secret_type              = "symmetric"
  algorithm                = "AES"
  bit_length               = 256
  mode                     = "CBC"
}

# 시크릿 컨테이너 (여러 시크릿 묶음)
resource "openstack_keymanager_container_v1" "test" {
  name = "test-container"
  type = "generic"

  secret_refs {
    name       = "db-password"
    secret_ref = openstack_keymanager_secret_v1.password.secret_ref
  }

  secret_refs {
    name       = "aes-key"
    secret_ref = openstack_keymanager_secret_v1.symmetric_key.secret_ref
  }
}
