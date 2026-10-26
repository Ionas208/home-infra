# Non-secret environment configuration. This file is committed on purpose so
# the VM inventory is reviewable in Git.
#
# Never put credentials here. The Proxmox API token is supplied through
# PROXMOX_VE_API_TOKEN.

proxmox_endpoint = "https://192.168.178.249:8006/"
proxmox_insecure = true

node_name    = "proxmox"
datastore_id = "local-lvm"
iso_file     = "local:iso/talos-v1.14.4-metal-amd64.iso"
bridge       = "vmbr0"

vms = {
  talos-cp-1 = {
    vm_id     = 101
    ip        = "192.168.178.240"
    cores     = 2
    memory    = 4096
    disk_size = 30
    role      = "controlplane"
  }
}
