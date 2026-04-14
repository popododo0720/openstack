#!/usr/bin/env python3
import ipaddress
import json
from pathlib import Path


ROOT = Path("/root/openstack/deploy-airgap")
INVENTORY = ROOT / "inventory.ini"
TF_ROOT = ROOT / "terraform"


def parse_inventory(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    section = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section != "all:vars" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key.strip()] = value.strip().strip("'").strip('"')
    return data


def split_words(value: str | None) -> list[str]:
    if not value:
        return []
    return [item for item in value.split() if item]


def first_host(cidr: str) -> str:
    net = ipaddress.ip_network(cidr, strict=False)
    return str(next(net.hosts()))


def host_offset(cidr: str, offset: int) -> str:
    net = ipaddress.ip_network(cidr, strict=False)
    if net.version != 4:
        raise ValueError("Only IPv4 is supported for Terraform inventory rendering")
    base = int(net.network_address)
    return str(ipaddress.ip_address(base + offset))


def default_external_pools(cidr: str) -> list[dict[str, str]]:
    return [
        {"start": host_offset(cidr, 24), "end": host_offset(cidr, 29)},
        {"start": host_offset(cidr, 42), "end": host_offset(cidr, 51)},
        {"start": host_offset(cidr, 53), "end": host_offset(cidr, 57)},
    ]


def parse_pools(value: str | None, cidr: str) -> list[dict[str, str]]:
    if not value:
        return default_external_pools(cidr)
    pools: list[dict[str, str]] = []
    for chunk in value.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        start, end = [item.strip() for item in chunk.split("-", 1)]
        pools.append({"start": start, "end": end})
    return pools


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    inv = parse_inventory(INVENTORY)

    region = inv.get("region", "RegionOne")
    external_vip = inv["kolla_external_vip_address"]
    auth_url = inv.get("terraform_auth_url", f"https://{external_vip}:5000/v3")
    admin_password = inv["admin_password"]
    site_dns = split_words(inv.get("site_dns_servers")) or ["1.1.1.1", "8.8.8.8"]
    external_cidr = inv.get("external_network", "192.168.0.0/24")
    external_gateway = inv.get("external_gateway", first_host(external_cidr))

    common = {
        "auth_url": auth_url,
        "admin_password": admin_password,
        "region": region,
    }

    tf01 = {
        **common,
        "external_network_cidr": external_cidr,
        "external_gateway": external_gateway,
        "external_dns": site_dns,
        "tenant_dns": site_dns,
        "external_allocation_pools": parse_pools(inv.get("terraform_external_allocation_pools"), external_cidr),
    }

    tf03 = {
        **common,
        "internal_network_name": inv.get("terraform_internal_network_name", "internal-net"),
        "internal_subnet_name": inv.get("terraform_internal_subnet_name", "internal-subnet"),
        "router_name": inv.get("terraform_router_name", "main-router"),
        "instance_name": inv.get("terraform_internal_fip_instance_name", "internal-fip-vm-1"),
        "floating_ip_pool": inv.get("terraform_floating_ip_pool", "external-net"),
    }

    internal_cidr = inv.get("terraform_internal_network_cidr") or inv.get("tunnel_network")
    if internal_cidr:
        tf03["internal_network_cidr"] = internal_cidr
        tf03["internal_gateway_ip"] = inv.get("terraform_internal_gateway_ip", first_host(internal_cidr))
        tf03["internal_dns"] = split_words(inv.get("terraform_internal_dns")) or site_dns
        tf03["fixed_ip"] = inv.get("terraform_internal_fixed_ip", host_offset(internal_cidr, 20))

    write_json(TF_ROOT / "01-base" / "zz_inventory.auto.tfvars.json", tf01)
    write_json(TF_ROOT / "02-instance" / "zz_inventory.auto.tfvars.json", common)
    write_json(TF_ROOT / "03-internal-fip" / "zz_inventory.auto.tfvars.json", tf03)

    print("Rendered:")
    print(TF_ROOT / "01-base" / "zz_inventory.auto.tfvars.json")
    print(TF_ROOT / "02-instance" / "zz_inventory.auto.tfvars.json")
    print(TF_ROOT / "03-internal-fip" / "zz_inventory.auto.tfvars.json")


if __name__ == "__main__":
    main()
