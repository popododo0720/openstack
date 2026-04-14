#!/bin/bash
set -euo pipefail
python3 /root/openstack/deploy-airgap/terraform/render-tfvars-from-inventory.py
