variable "name" {
  description = "VM name, also used as the Talos hostname."
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID."
  type        = number
}

variable "role" {
  description = "Talos role: controlplane or worker."
  type        = string
}

variable "ip" {
  description = "Planned LAN address. Documentation only, Talos configures the interface."
  type        = string
}

variable "cores" {
  description = "Number of vCPU cores."
  type        = number
}

variable "memory" {
  description = "Dedicated memory in MiB."
  type        = number
}

variable "disk_size" {
  description = "Boot disk size in GiB."
  type        = number
}

variable "node_name" {
  description = "Proxmox node that hosts the VM."
  type        = string
}

variable "datastore_id" {
  description = "Proxmox storage for the boot disk."
  type        = string
}

variable "iso_file" {
  description = "Talos ISO volume ID."
  type        = string
}

variable "bridge" {
  description = "Proxmox bridge for the VM NIC."
  type        = string
}
