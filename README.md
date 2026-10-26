# home-infra

Foundation for the Seidl home lab. This repository creates the hosts and the Talos
cluster; Kubernetes workloads live in [`home-gitops`](https://github.com/Ionas208/home-gitops).

This repository is public. It must never contain Terraform state, Talos secrets,
kubeconfigs, API tokens, private keys, or unencrypted Ansible secrets.

## Status

**Three-node cluster running.**

- `talos-cp-1` (VM 101), `talos-worker-1` (102), `talos-worker-2` (103), all managed by OpenTofu
- Talos v1.14.4, Kubernetes v1.37.1
- single-node etcd on the control plane; the control plane is untainted and schedulable
- Argo CD is not installed yet

## Documentation

- [`docs/README.md`](docs/README.md) — documentation index
- [`docs/bootstrap.md`](docs/bootstrap.md) — Phase 1 bootstrap runbook
- [`docs/network.md`](docs/network.md) — address plan, DNS, ingress, QNAP, firewall
- [`docs/inventory.md`](docs/inventory.md) — Proxmox host, QNAP, Talos VM sizing

## Structure

```text
tofu/          Proxmox VM provisioning (envs/proxmox + modules/proxmox-vm)
talos/         machine config patches and the generator script
bootstrap/     day-0 scripts
ansible/       Proxmox host configuration (not used yet)
```

## Phase 1 target

- Proxmox on the current Xeon E3 host
- three Talos VMs: one control plane, two workers
- control-plane scheduling enabled
- Argo CD bootstrap from `home-gitops`

The current cluster is disposable. When the new server arrives, rebuild with the control
plane on the new host.

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

## Placeholders

IP addresses are RFC 5737 TEST-NET-1 placeholders:

| Placeholder | Example |
|---|---|
| `<LAN_CIDR>` | `192.0.2.0/24` |
| `<PROXMOX_IP>` | `192.0.2.5` |
| `<TALOS_CP_IP>` | `192.0.2.10` |
| `<TALOS_WORKER1_IP>` | `192.0.2.11` |
| `<TALOS_WORKER2_IP>` | `192.0.2.12` |
| `<TRAEFIK_VIP>` | `192.0.2.50` |
| `<DNS_VIP>` | `192.0.2.53` |
| `<QNAP_IP>` | `192.0.2.254` |

Replace them before deployment. They are not routable.
