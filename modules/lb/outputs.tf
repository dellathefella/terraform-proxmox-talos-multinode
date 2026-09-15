output "lb_ip" {
  description = "IP address of the primary load balancer LXC."
  value       = var.lb_ip
}

output "lb_container_ids" {
  description = "Proxmox CT IDs of the load balancer LXC(s), keyed by instance role."
  value       = { for k, ct in proxmox_virtual_environment_container.cluster_lb : k => ct.vm_id }
}
