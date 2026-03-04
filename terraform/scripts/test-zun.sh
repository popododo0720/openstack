#!/bin/bash
# ===========================================
# Zun 컨테이너 테스트 (Terraform 미지원 → CLI)
# ===========================================
# 사용법: source /etc/kolla/admin-openrc.sh && bash test-zun.sh
set -e

echo "=== Zun 서비스 상태 확인 ==="
openstack appcontainer service list

echo ""
echo "=== 컨테이너 생성 (nginx) ==="
openstack appcontainer create \
  --name test-nginx \
  --net network=tenant-net \
  --security-group test-secgroup \
  --image nginx:alpine \
  --cpu 0.5 \
  --memory 256 \
  --restart-policy on-failure:3

echo ""
echo "=== 컨테이너 시작 ==="
openstack appcontainer start test-nginx

echo ""
echo "=== 상태 확인 (10초 대기) ==="
sleep 10
openstack appcontainer show test-nginx

echo ""
echo "=== 로그 확인 ==="
openstack appcontainer logs test-nginx

echo ""
echo "=== 정리하려면 ==="
echo "openstack appcontainer delete --force test-nginx"
