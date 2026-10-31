# Proxmox host setup

> As-built runbook for the single-node Proxmox host. It records what was done so
> the host can be rebuilt the same way. The Talos VM is covered in
> [`bootstrap.md`](bootstrap.md).

## Host

| Item                 | Value                                              |
|----------------------|----------------------------------------------------|
| Hardware             | Intel Core i5-9400T, 6C/6T, 16 GB RAM, 256 GB NVMe |
| Proxmox VE           | 9.2.2 (kernel `7.0.2-6-pve`)                       |
| Node name            | `proxmox`                                          |
| FQDN                 | `proxmox.fujitsu`                                  |
| Management IP        | `192.168.178.249/24`                               |
| Gateway / DNS        | `192.168.178.1`                                    |
| NIC / bridge         | `nic0` / `vmbr0`                                   |
| Web UI               | `https://192.168.178.249:8006`                     |
| VM datastore         | `local-lvm`, LVM-thin, 140.9 GiB                   |
| ISO datastore        | `local`, ~60 GiB free                              |
| Backup storage       | `qnap-backups` → `192.168.178.254:/k8s-backups`    |
| Talos VM             | VM 101, `talos-cp-1`, `192.168.178.239`            |

## 1. Install

Proxmox VE 9.2.2 was installed on `nvme0n1` (238.5 GiB) with LVM-thin for VM
disks.

| Installer choice | Value                                |
|------------------|--------------------------------------|
| Disk             | `nvme0n1`                            |
| Storage          | LVM with LVM-thin for VM disks       |
| Swap             | 8 GiB                                |
| Root             | 68 GiB (`pve-root`)                  |
| VM pool          | 140.9 GiB (`pve-data` / `local-lvm`) |
| Hostname         | `proxmox.fujitsu`                    |
| IP address       | `192.168.178.249/24`                 |
| Gateway          | `192.168.178.1`                      |
| DNS              | `192.168.178.1`                      |

The short hostname is `proxmox`, which is the Proxmox node name and matches
`node_name` in `tofu/envs/proxmox/terraform.tfvars`.

The web UI is reachable at `https://192.168.178.249:8006` as `root` with the
Linux PAM realm.

## 2. Repositories and updates

Disable the enterprise repositories and use the no-subscription repository. This
also disables the Ceph enterprise repo; Ceph is not used on this host.

```bash
grep -rl 'enterprise.proxmox.com' /etc/apt/sources.list.d/ \
  | while read -r f; do mv "$f" "$f.disabled"; done

CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "deb http://download.proxmox.com/debian/pve $CODENAME pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

apt update
apt full-upgrade -y
```

PVE 9.2.2 runs on Debian 13 (`trixie`), so the resulting repository line is:

```text
deb http://download.proxmox.com/debian/pve trixie pve-no-subscription
```

The host was updated manually with `apt full-upgrade`. Do not enable automatic
reboots; the Talos VM runs on this host.

## 3. Storage

The installer created the following layout:

| Storage     | Type     | Size      | Used    | Free      |
|-------------|----------|-----------|---------|-----------|
| `local-lvm` | LVM-thin | 140.9 GiB | 0       | 140.9 GiB |
| `local`     | dir      | 67.6 GiB  | 4.1 GiB | 60.0 GiB  |
| `pve-root`  | LVM      | 68 GiB    | 4.2 GiB | 60 GiB    |

`local-lvm` holds the Talos VM disk. The 100 GiB VM disk is thin-provisioned and
leaves about 40.9 GiB of thin-pool headroom for snapshots.

`local` holds ISOs and templates. Enable its content types:

```bash
pvesm set local --content iso,vztmpl,backup
pvesm status
```

## 4. Talos ISO

The node runs a **Talos Image Factory** build, not the upstream release ISO. The
schematic in `talos/schematic.yaml` adds `siderolabs/nfs-utils`, which
`csi-driver-nfs` needs on the node, and the factory bakes it into the ISO and the
installer image.

| Item | Value |
|------|-------|
| Schematic ID | `1b03b1684045f858942e25dda57c45df1fb8ce3479a790e041395905171a72db` |
| ISO | `https://factory.talos.dev/image/<schematic-id>/v1.14.4/metal-amd64.iso` |
| Installer | `factory.talos.dev/metal-installer/<schematic-id>:v1.14.4` |
| Local name | `talos-v1.14.4-nfs-amd64.iso` |

Download it directly on the Proxmox host and place it in the `local` ISO storage
with the name expected by `terraform.tfvars`:

```bash
cd /var/lib/vz/template/iso

SCHEMATIC=1b03b1684045f858942e25dda57c45df1fb8ce3479a790e041395905171a72db
curl -fL --retry 3 -o talos-v1.14.4-nfs-amd64.iso \
  "https://factory.talos.dev/image/${SCHEMATIC}/v1.14.4/metal-amd64.iso"

file talos-v1.14.4-nfs-amd64.iso    # ISO 9660 ... 'TALOS_V1_14_4'
pvesm list local --content iso
```

Expected volume:

```text
local:iso/talos-v1.14.4-nfs-amd64.iso
```

This matches `iso_file` in `tofu/envs/proxmox/terraform.tfvars`.

The schematic ID is a content hash of `talos/schematic.yaml`, so it changes
whenever the extension list changes:

```bash
curl -sX POST --data-binary @talos/schematic.yaml \
  https://factory.talos.dev/schematics
```

When the ID changes, update it in `talos/generate.sh` (`SCHEMATIC_ID`), this
section, and `iso_file`, then re-download the ISO. Never upgrade the node with a
plain `ghcr.io` installer image: that reverts the extensions.

```bash
talosctl --nodes 192.168.178.239 upgrade \
  --image "factory.talos.dev/metal-installer/${SCHEMATIC}:v1.14.4" \
  --preserve=true
```

`--preserve` keeps `EPHEMERAL`, so container images and any `local-path` data
survive. Afterwards, confirm the node is schedulable: the `unschedulable` taint
can outlive the upgrade even when `talosctl` reports the node uncordoned, which
leaves every pod `Pending`.

```bash
kubectl get node talos-cp-1 -o jsonpath='{range .spec.taints[*]}{.key}{"\n"}{end}'
kubectl uncordon talos-cp-1    # only if unschedulable is still listed
```

## 5. OpenTofu access

Create the dedicated role, user, token, and ACLs used by OpenTofu.

```bash
pveum role add TofuProvisioner -privs "VM.Allocate,VM.Audit,VM.Config.CPU,VM.Config.Memory,VM.Config.Disk,VM.Config.Network,VM.Config.Options,VM.Config.HWType,VM.Config.CDROM,VM.PowerMgmt,Datastore.AllocateSpace,Datastore.Audit,SDN.Use,Sys.Audit"

pveum user add tofu@pve --comment "OpenTofu automation"

pveum user token add tofu@pve tofu --privsep 1

pveum acl modify / --users tofu@pve --roles TofuProvisioner --propagate 1
pveum acl modify / --tokens 'tofu@pve!tofu' --roles TofuProvisioner --propagate 1
```

The token value is printed once. Bitwarden Secrets Manager stores only the
secret; the provider token is `tofu@pve!tofu=<secret>`. It can be read with the
Bitwarden CLI (`bws`); ESO (External Secrets Operator) handles the cluster-side
secret sync.

`--privsep 1` means the token's effective permissions are the intersection of the
user's and token's permissions, so both ACLs above are required.

Verify the effective permissions:

```bash
pveum user permissions 'tofu@pve!tofu'
```

## 6. Verification

On the Proxmox host:

```bash
pveversion -v
hostname -f
ip -br address
pvesm status
pvesm list local --content iso
pveum user permissions 'tofu@pve!tofu'
systemctl list-timers etcd-snapshot.timer
```

On the workstation:

Bitwarden stores only the token secret. The provider needs the full
`tofu@pve!tofu=<secret>` value, so add the prefix when exporting:

```bash
export PROXMOX_VE_API_TOKEN="tofu@pve!tofu=$(bws secret get <secret-id> -o json | jq -r .value)"
cd tofu/envs/proxmox
tofu init
tofu plan
```

Expected on a fresh state: one VM to create, `talos-cp-1`.

## 7. QNAP NFS storage and backups

The QNAP at `192.168.178.254` exports two shares over NFSv4.1. Access is
restricted to explicit client IPs and uses **no root squash**, because Proxmox
writes `vzdump` files as root. A subnet-wide export would let anything on the LAN
write as root, so do not widen it.

| Share | Export | Allowed client | Use |
|-------|--------|----------------|-----|
| `k8s` | `192.168.178.254:/k8s` | `192.168.178.239` | Kubernetes PVCs |
| `k8s-backups` | `192.168.178.254:/k8s-backups` | `192.168.178.249` | VM and etcd backups |

| Volume | Size | Snapshots | Purpose |
|--------|------|-----------|---------|
| `k8s` | 256 GB thick | ~20% reserve, hourly keep 24, daily keep 14 | live PVC data |
| `k8s-backups` | 512 GB thick | none | backups |

Snapshots are not a backup: they share the array with the data they protect.
RAID 5 covers one disk failure only, so both an offsite copy and a restore test
are still outstanding. There is also no UPS.

Verify the export from the host:

```bash
showmount -e 192.168.178.254

mkdir -p /mnt/test
mount -t nfs4 192.168.178.254:/k8s-backups /mnt/test
touch /mnt/test/probe
ls -ln /mnt/test/probe    # must be uid 0; 65534 means root squash is on
umount /mnt/test && rmdir /mnt/test
```

### Proxmox storage

```bash
pvesm add nfs qnap-backups \
  --server 192.168.178.254 \
  --export /k8s-backups \
  --content backup \
  --options vers=4.1

pvesm status
```

`pvesm status` must show `qnap-backups` as active. Proxmox creates a `dump/`
directory under the export; leave it alone and keep the etcd snapshots in a
sibling `etcd/` directory.

### VM backups

The scheduled job lives under **Datacenter → Backup**:

| Setting | Value |
|---------|-------|
| Node | `proxmox` |
| VM | 101 (`talos-cp-1`) |
| Schedule | daily `03:00` |
| Mode | snapshot |
| Compression | zstd |
| Retention | keep-daily 7, keep-weekly 4, keep-monthly 2 |

Snapshot mode backs up an LVM-thin snapshot, so the VM keeps running. Manual
test, which also reports the real backup size:

```bash
vzdump 101 --storage qnap-backups --mode snapshot --compress zstd
ls -lh /mnt/pve/qnap-backups/dump/
```

### etcd snapshots

Talos has no built-in scheduled etcd backup, so the host runs one. `talosctl`
v1.14.4 is installed at `/usr/local/bin/talosctl`, and the cluster admin
talosconfig lives at `/root/.talos/config`, mode `0600`. That file is a root
credential; it belongs in the recovery kit, not in a shell history.

`/usr/local/sbin/etcd-snapshot.sh` (`0750`) writes
`etcd-YYYY-MM-DD_HHMM.snapshot` to `/mnt/pve/qnap-backups/etcd/`, keeps the
newest 30, and exits non-zero when the NFS mount is absent. `etcd-snapshot.timer`
runs it daily at `02:30`, before the `03:00` VM backup, so the VM image is never
ahead of the most recent object-level restore point.

```bash
systemctl list-timers etcd-snapshot.timer
journalctl -u etcd-snapshot.service -n 20 --no-pager
ls -lh /mnt/pve/qnap-backups/etcd/
```

An etcd snapshot contains every Kubernetes Secret in plaintext. Keep this share
NFS-only, and encrypt any offsite copy.

### Restore pointers

- VM: `qmrestore /mnt/pve/qnap-backups/dump/vzdump-qemu-101-*.vma.zst 101`
- etcd: reset the node, then `talosctl bootstrap --recover-from=<snapshot>`
- Neither path has been exercised yet. Run a restore test before trusting the
  backup job.

## 8. Host metrics

Prometheus runs inside the Talos VM, so it cannot see this host. A
`prometheus-node-exporter` on the Proxmox host covers the host's CPU, memory,
filesystems and network, and the cluster scrapes it over the LAN.

```bash
apt-get install -y prometheus-node-exporter

sed -i 's|^ARGS=.*|ARGS="--collector.textfile.directory=/var/lib/prometheus/node-exporter"|' \
  /etc/default/prometheus-node-exporter
systemctl restart prometheus-node-exporter
```

The textfile collector turns host facts into metrics that node-exporter cannot
derive from `/proc`. The source lives in `host/node-exporter/`:

```bash
install -m 0750 host/node-exporter/node-textfile-metrics.sh /usr/local/sbin/
install -m 0644 host/node-exporter/node-textfile-metrics.{service,timer} /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now node-textfile-metrics.timer
```

| Metric | Meaning |
|--------|---------|
| `node_reboot_required` | `1` when `/var/run/reboot-required` exists |
| `pve_apt_upgradable` | packages with an available upgrade |
| `pve_thinpool_used_percent` | used percentage of the `pve/data` thin pool |

The thin pool is the important one: `local-lvm` is not a mounted filesystem, so
`node_filesystem_*` cannot see it, and exhausting it breaks `vzdump` snapshots
and new VM disks.

The cluster scrapes `192.168.178.249:9100` as the `proxmox-host` job
(`platform/observability/config/60-scrapeconfigs.yaml` in `home-gitops`). The
endpoint has no authentication. With `pve-firewall` enabled, allow TCP `9100`
from `192.168.178.239` only; firewall is currently disabled on this host, so the
rule is documentation for the future.

`ProxmoxRebootRequired` fires after one hour and must never auto-reboot: this
host runs the only etcd member and every workload.

## 9. Not done yet

- Offsite copy. Every backup sits on one NAS with no UPS, so RAID 5 and the NAS
  itself are both single points of failure. Plan HBS 3 to Backblaze B2 or
  Cloudflare R2, with client-side encryption because etcd snapshots contain
  secrets.
- Restore test for `vzdump` and etcd snapshots.
- Grafana/alerting. When it exists, add a pending-reboot alert for this host (`/var/run/reboot-required` after
  unattended updates). The host is outside
  Kubernetes, so it needs a host-side check/metric.