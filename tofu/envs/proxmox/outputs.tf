output "vms" {
  description = "Provisioned VMs with their planned addresses."

  value = {
    for name, vm in module.vm : name => {
      vm_id = vm.vm_id
      ip    = var.vms[name].ip
      role  = var.vms[name].role
    }
  }
}
