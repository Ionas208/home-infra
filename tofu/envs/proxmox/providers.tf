provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure

  # The API token is read from PROXMOX_VE_API_TOKEN so it never appears in
  # HCL, tfvars, plan files, or state. Set it before running tofu.
}
