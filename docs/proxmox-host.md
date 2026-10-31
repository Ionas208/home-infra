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
| ISO/backup datastore | `local`, ~60 GiB free                              |
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

`local` holds ISOs and temporary backups. Enable its ISO content:

```bash
pvesm set local --content iso,vztmpl,backup
pvesm status
```

## 4. Talos ISO

Download the ISO directly on the Proxmox host, verify it, and place it in the
`local` ISO storage with the name expected by `terraform.tfvars`.

```bash
cd /var/lib/vz/template/iso

curl -fL --retry 3 -O \
  https://github.com/siderolabs/talos/releases/download/v1.14.4/metal-amd64.iso
curl -fL --retry 3 -O \
  https://github.com/siderolabs/talos/releases/download/v1.14.4/sha256sum.txt

sha256sum -c sha256sum.txt --ignore-missing
mv metal-amd64.iso talos-v1.14.4-metal-amd64.iso
rm sha256sum.txt

pvesm list local --content iso
```

Expected volume:

```text
local:iso/talos-v1.14.4-metal-amd64.iso
```

This matches `iso_file` in `tofu/envs/proxmox/terraform.tfvars`. If the Talos
version changes, update the download URL and `iso_file` together.

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

## 7. Not done yet

- QNAP NFS storage and the Proxmox backup job. The NAS is not configured yet.
- Grafana/alerting. When it exists, add a pending-reboot alert for this host (`/var/run/reboot-required` after
  unattended updates). The host is outside
  Kubernetes, so it needs a host-side check/metric.