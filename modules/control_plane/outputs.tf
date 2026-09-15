output "vm_ids" {
  description = "Control plane Proxmox VM IDs, keyed by node name."
  value       = { for k, vm in proxmox_virtual_environment_vm.vm : k => vm.vm_id }
}
