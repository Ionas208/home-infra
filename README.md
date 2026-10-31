# home-infra

Foundation for the Seidl home lab. This repository creates the hosts and the Talos
cluster; Kubernetes workloads live in [`home-gitops`](https://github.com/Ionas208/home-gitops).

This repository is public. It must never contain Terraform state, Talos secrets,
kubeconfigs, API tokens, private keys, or unencrypted Ansible secrets.

## Status

**Single-node cluster.**

- one Proxmox VE 9.2.2 host (i5-9400T, 16 GB RAM, 256 GB SSD) at `192.168.178.249`, FQDN `proxmox.fujitsu`
- `talos-cp-1` (VM 101), managed by OpenTofu, runs the control plane and all workloads
- Talos v1.14.4, Kubernetes v1.37.1
- single-member etcd; the control plane is untainted and schedulable
- the old three-node host is retired but kept intact and can be powered on later
- Argo CD is not installed yet

## Documentation

- [`docs/README.md`](docs/README.md) — documentation index
- [`docs/proxmox-host.md`](docs/proxmox-host.md) — Proxmox install, storage, OpenTofu role/token
- [`docs/bootstrap.md`](docs/bootstrap.md) — Talos VM bootstrap runbook
- [`docs/network.md`](docs/network.md) — address plan, DNS, ingress, QNAP, firewall
- [`docs/inventory.md`](docs/inventory.md) — Proxmox host, QNAP, Talos VM sizing

## Structure

```text
tofu/          Proxmox VM provisioning (envs/proxmox + modules/proxmox-vm)
talos/         machine config patches and the generator script
bootstrap/     day-0 scripts
ansible/       Proxmox host configuration (planned)
```

## Design

- Proxmox VE 9.2.2 on the power-efficient i5-9400T host
- one Talos VM: the control plane, with scheduling enabled
- Argo CD bootstrap from `home-gitops`

A single VM keeps the whole 16 GB box usable for workloads and avoids an etcd
quorum that spans two VMs on the same physical host. If more capacity is needed
later, add workers (VMs on this host or the retired host), not a second control
plane on the same box. Do not run a two-member control plane: etcd would need
both members up to have quorum.

## Secrets

Committed: `tofu/envs/proxmox/terraform.tfvars` (IPs, VM IDs, sizing).

Never committed, all gitignored:

- `tofu/` state and `.terraform/`
- `talos/secrets/secrets.yaml`
- `talos/generated/` (machine configs, talosconfig)
- kubeconfig

The Proxmox API token comes from the environment:

```bash
export PROXMOX_VE_API_TOKEN="tofu@pve!tofu=<secret>"
```

## Addresses

The docs use the real private LAN (`192.168.178.0/24`) so they match the
committed `terraform.tfvars`. Private RFC 1918 addresses are not secrets, but do
not add public IPs, credentials, or hostnames you do not want published.
