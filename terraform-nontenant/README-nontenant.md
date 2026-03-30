Provider-only / no-tenant-network variant

- Uses external-net only; tenant-net and main-router are not created.
- Leaves tunnel NIC present at the host level, but workloads are attached to provider/external network only.
- run.sh all intentionally runs only 01-base, 02-instance, 03-internal-fip, 05-ubuntu for provider-only validation. 03-internal-fip creates a small internal network, router, internal VM, and floating IP path.
- Alloy bootstrap continues to remote_write to http://vminsert.monitoring.local:8480 via 192.168.0.60 hosts fallback.
