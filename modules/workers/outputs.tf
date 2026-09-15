output "vm_ids" {
  description = "Worker Proxmox VM IDs, keyed by '<pool-name>-<index>'."
  value       = { for k, vm in proxmox_virtual_environment_vm.vm : k => vm.vm_id }
}
