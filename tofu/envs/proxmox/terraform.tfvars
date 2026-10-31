# Non-secret environment configuration. This file is committed on purpose so
# the VM inventory is reviewable in Git.
#
# Never put credentials here. The Proxmox API token is supplied through
# PROXMOX_VE_API_TOKEN.
#
# Single-node layout: one Proxmox host, one Talos VM. That VM is the control
# plane and runs every workload. The `vms` map is still keyed by hostname, so
# adding a worker later only requires another entry with a fresh VM ID and IP.

proxmox_endpoint = "https://192.168.178.249:8006/"
proxmox_insecure = true

# Must match the node name shown in the Proxmox UI (the installer default is
# `pve`; this host is named `proxmox`).
node_name    = "proxmox"
datastore_id = "local-lvm"
iso_file     = "local:iso/talos-v1.14.4-metal-amd64.iso"
bridge       = "vmbr0"

vms = {
  talos-cp-1 = {
    vm_id = 101
    # Outside the MetalLB pool (.243-.248); .240-.242 stay reserved for the
    # retired host's VMs.
    ip        = "192.168.178.239"
    cores     = 6     # i5-9400T has 6 threads; one VM can use all of them.
    memory    = 14336 # 14 GiB guest, ~2 GiB for the host.
    disk_size = 100   # GiB on the 256 GB SSD.
    role      = "controlplane"
  }
}
