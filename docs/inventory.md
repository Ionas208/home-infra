# Inventory

> Status: single-node Phase 1. The new host is installed; the old host is retired.

## Proxmox host (current)

| Item | Value |
|---|---|
| CPU | Intel Core i5-9400T, 6C/6T, 35 W |
| RAM | 16 GB |
| OS disk | 256 GB NVMe SSD (`nvme0n1`, 238.5 GiB) |
| VM storage | `local-lvm` LVM-thin, 140.9 GiB, 0 used |
| ISO/backup storage | `local` directory on `pve-root`, ~60 GiB free |
| GPU | integrated (console only) |
| Bulk storage | QNAP over NFS (not configured yet) |
| Hypervisor | Proxmox VE 9.2.2 (kernel 7.0.2-6-pve) |
| Hostname | `proxmox.fujitsu` |
| NIC / bridge | `nic0` / `vmbr0` |
| Address | `192.168.178.249` |
| Purpose | single-node lab; control plane and all workloads |

## Retired host

| Item | Value |
|---|---|
| CPU | Intel Xeon E3-1231v3, 4C/8T |
| RAM | 24 GB DDR3 |
| OS disk | 256 GB SATA SSD |
| GPU | passive GT 710 (console only) |
| Status | powered off; kept for extra capacity |
| Note | it used `.249`; change its address before powering it on again |

Do not run both hosts on `.249` at the same time.

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
| Address | `192.168.178.254` |
| Status | not configured yet |
| Snapshots | supported; confirm thick volume |
| UPS | none |

Keep the TS-433 as a pure NAS. Do not run Container Station or VMs on it.

## Talos VMs

The single-node layout provisions exactly one VM. The worker rows are not
provisioned; `.240` is reserved for the retired host's control plane and
`.241`/`.242` for its workers. The new control plane uses `.239`, below the
MetalLB pool (`.243`-`.248`).

| Name | Role | vCPU | RAM | Disk | Address |
|---|---|---|---|---|---|
| `talos-cp-1` | control plane + workloads | 6 | 14 GB | 100 GB | `192.168.178.239` |
| `talos-worker-1` | optional future worker | 2 | 6 GB | 40 GB | `192.168.178.241` |
| `talos-worker-2` | optional future worker | 2 | 6 GB | 40 GB | `192.168.178.242` |

Provisioned totals: 6 vCPU, 14 GB RAM, 100 GB disk. The remaining ~2 GB of host
RAM covers Proxmox, LVM metadata, and headroom. Guest RAM is a ceiling; it is
allocated on demand, not reserved up front.

The control-plane VM uses one etcd member. Quorum is 1/1, so there is no split
brain, but the host is a single point of failure. Keep etcd snapshots and Proxmox
VM backups on the QNAP once it is configured. There is no UPS, so a power loss
shuts the VM down uncleanly.

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
