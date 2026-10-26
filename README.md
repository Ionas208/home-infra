# home-infra

Foundation for the Seidl home lab. This repository creates the hosts and the Talos
cluster; Kubernetes workloads live in [`home-gitops`](https://github.com/Ionas208/home-gitops).

This repository is public. It must never contain Terraform state, Talos secrets,
kubeconfigs, API tokens, private keys, or unencrypted Ansible secrets.

## Status

**Phase 0: documentation only.**

No OpenTofu, Talos, or Ansible implementation exists yet. The implementation scaffold
that was drafted early has been preserved outside the repository and will be
reintroduced in Phase 1.

## Documentation

- [`docs/README.md`](docs/README.md) — documentation index
- [`docs/bootstrap.md`](docs/bootstrap.md) — target Phase 1 bootstrap runbook
- [`docs/network.md`](docs/network.md) — address plan, DNS, ingress, QNAP, firewall
- [`docs/inventory.md`](docs/inventory.md) — Proxmox host, QNAP, Talos VM sizing

## Planned structure

Created in Phase 1, not present now:

```text
tofu/          Proxmox VM provisioning
talos/         Talos machine config patches and generation scripts
ansible/       Proxmox host configuration
bootstrap/     day-0 scripts
```

## Phase 1 target

- Proxmox on the current Xeon E3 host
- three Talos VMs: one control plane, two workers
- control-plane scheduling enabled
- Argo CD bootstrap from `home-gitops`

The current cluster is disposable. When the new server arrives, rebuild with the control
plane on the new host.

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
