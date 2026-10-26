# Inventory

> Status: Phase 0 inventory. Hardware is current; new server and UPS are pending.

## Proxmox host (current)

| Item | Value |
|---|---|
| CPU | Intel Xeon E3-1231v3, 4C/8T |
| RAM | 24 GB DDR3 |
| OS disk | 256 GB SATA SSD |
| GPU | passive GT 710 (console only) |
| Bulk storage | none; QNAP over NFS |
| Hypervisor | Proxmox VE, TBD |
| Address | `192.0.2.5` placeholder |
| Purpose | phase 1 lab host; disposable |

## Main server (ordered)

| Item | Value |
|---|---|
| Model/spec | TBD |
| Role | preferred future control-plane host |
| Status | not delivered |

## QNAP

| Item | Value |
|---|---|
| Model | TS-433-4G |
| CPU | ARM Cortex-A55, 4-core, 2.0 GHz |
| RAM | 4 GB, non-expandable |
| Firmware | QTS 5.2.9.3410 |
| Bays | 4 |
| Disks | 4x Seagate IronWolf ST4000VN006, 4 TB |
| RAID | RAID 5 |
| Usable | ~10.9 TiB before snapshots/QTS overhead |
| Network | 1x 2.5GbE, 1x 1GbE |
| Address | `<LAN_PREFIX>.254` |
| Snapshots | supported; confirm thick volume |
| UPS | recommended; model TBD |

Keep the TS-433 as a pure NAS. Do not run Container Station or VMs on it.

## Talos VMs

| Name | Role | vCPU | RAM | Disk | Address |
|---|---|---|---|---|---|
| `talos-cp-1` | control plane + workloads | 2 | 4 GB | 40 GB | `192.0.2.10` |
| `talos-worker-1` | worker | 2 | 6 GB | 50 GB | `192.0.2.11` |
| `talos-worker-2` | worker | 2 | 6 GB | 50 GB | `192.0.2.12` |

Totals: 6 vCPU, 16 GB RAM, 140 GB disk.

## QNAP shares

| Share | Purpose | Suggested quota |
|---|---|---|
| `/k8s` | dynamic PVCs, shared data | 1.5 TB |
| `/media` | media library | 5 TB |
| `/backups` | Proxmox, etcd, restic | 2.5 TB |
| `/isos` | Proxmox ISOs | 100 GB |

Leave 10-20% free for snapshots and growth.

## Domain

- Public: `jonasseidl.com`
- Internal: `home.jonasseidl.com`
- Public DNS: explicit Cloudflare records, no wildcard
- Internal DNS: `lan-dns` CoreDNS in Kubernetes
- Internal TLS: Let's Encrypt wildcard via Cloudflare DNS-01

## Versions to pin

- Proxmox VE
- Talos
- Kubernetes
- Argo CD chart
- Traefik chart
- cert-manager chart
- External Secrets Operator chart
- MetalLB chart
- Tailscale operator chart
- csi-driver-nfs chart
- local-path-provisioner chart
- metrics-server chart
- cloudflared image
- app images
