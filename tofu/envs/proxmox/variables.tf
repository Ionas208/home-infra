variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint."
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the self-signed Proxmox certificate."
  type        = bool
}

variable "node_name" {
  description = "Proxmox node that hosts the VMs."
  type        = string
}

variable "datastore_id" {
  description = "Proxmox storage for VM boot disks."
  type        = string
}

variable "iso_file" {
  description = "Talos ISO volume ID on Proxmox."
  type        = string
}

variable "bridge" {
  description = "Proxmox bridge for VM NICs."
  type        = string
}

variable "vms" {
  description = "Talos VMs to create, keyed by hostname."

  type = map(object({
    vm_id     = number
    ip        = string
    cores     = number
    memory    = number
    disk_size = number
    role      = string
  }))

  validation {
    condition     = alltrue([for vm in values(var.vms) : contains(["controlplane", "worker"], vm.role)])
    error_message = "Each VM role must be either controlplane or worker."
  }
}
