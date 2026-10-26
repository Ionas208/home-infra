# Bootstrap

> Status: Phase 1 runbook. The control plane is deployed; the worker steps are
> Phase 1B. All addresses are placeholders in the documentation; the committed
> `tofu/envs/proxmox/terraform.tfvars` holds the real values.

End-to-end day-0 sequence. This repository creates the hosts and the Talos cluster;
Argo CD then reconciles `home-gitops`.

All addresses are placeholders. Replace them before running anything.

## 0. Prerequisites

- Proxmox VE installed on `<PROXMOX_IP>`
- Proxmox API token with least privilege
- Talos ISO uploaded to Proxmox `local` ISO storage
- QNAP reachable at `<QNAP_IP>` with NFS exports
- Cloudflare zone for `jonasseidl.com`
- Bitwarden Secrets Manager machine-account token
- `talosctl`, `kubectl`, `helm`, `tofu`, `ansible` installed locally
- `home-gitops` checked out next to this repository

## 1. Proxmox host

1. Install Proxmox VE on the 256 GB SSD.
   - Use LVM-thin (`local-lvm`) for VM disks.
   - Keep some free space; the SSD is small.
2. Set a static management IP: `<PROXMOX_IP>`.
3. Ensure `vmbr0` is bridged to the LAN.
4. Update the host:
   ```bash
   apt update && apt full-upgrade
   ```
5. Create an API token for OpenTofu:
   - Datacenter -> Permissions -> API Tokens
   - user: a dedicated automation user, not `root@pam`
   - role privileges: `VM.*`, `Datastore.AllocateSpace`, `Datastore.Audit`,
     `Sys.Audit`, `SDN.Use`
   - assign the role to the token or its user and group, with propagate on `/`
   - `SDN.Use` is required to attach a NIC to `vmbr0`
   - export it as `PROXMOX_VE_API_TOKEN`
6. Upload the Talos ISO to `local:iso/`.
7. Optional: run the Ansible playbook:
   ```bash
   cd ansible
   ansible-playbook -i inventories/home/hosts.yml playbooks/proxmox-host.yml
   ```

## 2. Talos VMs with OpenTofu

```bash
cd tofu/envs/proxmox
tofu init
tofu plan
tofu apply
```

`terraform.tfvars` is committed and holds the VM inventory. Phase 1A contains only
the control plane; worker entries are added in Phase 1B, which makes `tofu plan`
show exactly two creates and no changes to `talos-cp-1`.

Expected VMs:

| Name | Role | vCPU | RAM | Disk |
|---|---|---|---|---|
| `talos-cp-1` | control plane | 2 | 4 GB | 30 GB |
| `talos-worker-1` | worker | 2 | 6 GB | 40 GB |
| `talos-worker-2` | worker | 2 | 6 GB | 40 GB |

Total 110 GiB on a 130 GiB thin pool.

The VMs boot the Talos ISO. OpenTofu only creates the shells; Talos configuration is
applied with `talosctl`.

## 3. Talos configuration

```bash
cd talos
./generate.sh
```

Defaults: cluster `home`, control-plane endpoint `https://192.168.178.240:6443`.
Override with `CLUSTER_NAME` or `CP_IP` if needed.

This creates:

```text
talos/secrets/secrets.yaml        # gitignored; back this up
talos/generated/talos-cp-1.yaml   # machine config
talos/generated/talosconfig       # client credentials
```

Talos 1.14 emits a multi-document machine config. Fields that moved into their own
documents (`HostnameConfig`, `ResolverConfig`, `UnattendedInstallConfig`,
`KubeNodeConfig`) must be patched in those documents; duplicating them in the
legacy document is rejected at apply time. The specific conflicts and their
workarounds are commented in `talos/patches/`.

Back up `talos/secrets/secrets.yaml` to BSM and the offline recovery kit. Never commit it.

## 4. Bootstrap the cluster

Talos first boots into maintenance mode and uses **DHCP**, so the VM answers on a
lease, not on its final static address. Find that lease, then pass it:

```bash
export MAINTENANCE_IP=<DHCP_LEASE>
./bootstrap/02-talos.sh
```

The script:

1. applies the control-plane config (installs to `/dev/sda`, then reboots)
2. waits for the node on `CP_IP`
3. bootstraps etcd
4. writes `~/.kube/config` and renames the context to `home`
5. waits for `kubectl get nodes`

Verify:

```bash
kubectl get nodes -o wide
```

## 5. Argo CD

```bash
./bootstrap/03-argocd.sh
```

This calls `home-gitops/bootstrap/argocd/install.sh`. Follow
`home-gitops/docs/runbooks/bootstrap.md` for:

- pinning chart versions
- the BSM bootstrap Secret
- DNS cutover
- certificate verification
- public ingress verification

## 6. Storage

1. On the QNAP, create `/k8s`, `/media`, `/backups`, `/isos`.
2. Enable NFSv4.1 and export `/k8s` to the three Talos node IPs.
3. Export `/backups` to the Proxmox host and the Talos nodes.
4. Verify the Talos `nfs-utils` extension and NFS mount:
   ```bash
   kubectl -n kube-system get pods -l app=csi-nfs-node
   ```
5. Create a test PVC with `storageClassName: nfs-qnap`.

Do not make `nfs-qnap` the default StorageClass. `local-path` remains default.

## 7. Backups

1. Add QNAP `/backups` as Proxmox `vzdump` storage.
2. Schedule VM backups, especially `talos-cp-1`.
3. Schedule etcd snapshots to `/backups/etcd`.
4. Configure QNAP snapshots and HBS 3 offsite.
5. Restore test.

## 8. New server later

When the new server arrives:

1. Install Proxmox on it.
2. Rebuild the cluster with the control plane there.
3. Add the old host as workers or retire it.
4. Restore workloads from Git and persistent data from QNAP.

Do not migrate Talos control-plane roles in place.
