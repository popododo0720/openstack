#!/usr/bin/env bash
set -euo pipefail

GLOBALS="${GLOBALS:-/root/openstack/deploy-airgap/globals.yml}"
SRC="${SRC:-quay.io/openstack.kolla}"

read_yaml_scalar() {
  local key="$1"
  local file="$2"
  awk -F': ' -v key="$key" '$1 == key { gsub(/"/, "", $2); print $2; exit }' "$file"
}

REGISTRY="10.250.254.1:5001"
NAMESPACE="fxhci"
TAG="master-ubuntu-noble"

if [[ -f "$GLOBALS" ]]; then
  REGISTRY="$(read_yaml_scalar docker_registry "$GLOBALS" || true)"
  NAMESPACE="$(read_yaml_scalar docker_namespace "$GLOBALS" || true)"
  TAG="$(read_yaml_scalar openstack_tag "$GLOBALS" || true)"
  REGISTRY="${REGISTRY:-10.250.254.1:5001}"
  NAMESPACE="${NAMESPACE:-fxhci}"
  TAG="${TAG:-master-ubuntu-noble}"
fi

DST="${REGISTRY}/${NAMESPACE}"

if (($# == 0)); then
  echo "Usage: $0 <image1> [image2 ...]" >&2
  echo "Example: $0 prometheus-blackbox-exporter valkey-server" >&2
  exit 1
fi

command -v docker >/dev/null 2>&1 || {
  echo "docker command not found" >&2
  exit 1
}

for image in "$@"; do
  src_ref="${SRC}/${image}:${TAG}"
  dst_ref="${DST}/${image}:${TAG}"

  echo "==> ${image}"
  echo "pull: ${src_ref}"
  docker pull "${src_ref}"

  echo "tag:  ${dst_ref}"
  docker tag "${src_ref}" "${dst_ref}"

  echo "push: ${dst_ref}"
  docker push "${dst_ref}"
done
