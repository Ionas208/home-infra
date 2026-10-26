module "vm" {
  source   = "../../modules/proxmox-vm"
  for_each = var.vms

  name         = each.key
  vm_id        = each.value.vm_id
  role         = each.value.role
  ip           = each.value.ip
  cores        = each.value.cores
  memory       = each.value.memory
  disk_size    = each.value.disk_size
  node_name    = var.node_name
  datastore_id = var.datastore_id
  iso_file     = var.iso_file
  bridge       = var.bridge
}
