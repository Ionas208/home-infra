resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  description = "Talos ${var.role} ${var.ip} - managed by OpenTofu"
  tags        = ["talos", var.role, "managed-by-opentofu"]
  node_name   = var.node_name
  vm_id       = var.vm_id

  machine       = "q35"
  bios          = "seabios"
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true
  started       = true
  reboot        = false

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  cdrom {
    file_id   = var.iso_file
    interface = "ide3"
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  # Prefer the installed disk, fall back to the ISO while the disk is empty.
  boot_order = ["scsi0", "ide3"]

  lifecycle {
    ignore_changes = [
      # Proxmox rewrites these on its own.
      disk[0].file_id,
      cdrom[0].file_id,
    ]
  }
}
