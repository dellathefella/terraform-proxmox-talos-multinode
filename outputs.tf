output "cluster_lb_lxc_ip" {
  value = local.cluster_lb_lxc_ip
}

output "cluster_api_endpoint" {
  description = "The address the cluster API and ingress are reachable at (VIP when HA, primary LB otherwise)."
  value       = local.cluster_endpoint_ip
}

output "cluster_lb_lxc_user" {
  value = "root"
}

output "talos_control_plane_ips" {
  value = [
    for control_plane in local.listed_control_plane_nodes : control_plane.ip
  ]
}

output "talos_worker_ips" {
  description = "IP addresses of all worker nodes across all pools."
  value = [
    for worker in local.listed_worker_nodes : worker.ip
  ]
}

output "worker_ips_by_pool" {
  description = "Worker node IP addresses grouped by node pool name."
  value = {
    for pool in var.node_pools :
    pool.node_pool_settings.name => [
      for worker in local.listed_worker_nodes : worker.ip
      if worker.name == pool.node_pool_settings.name
    ]
  }
}

output "talos_schematic_id" {
  description = "Image Factory schematic ID used for the Talos disk images."
  value       = talos_image_factory_schematic.this.id
}

output "talos_version" {
  description = "Talos version installed on all nodes."
  value       = var.talos_version
}

output "kube_config" {
  description = "Kubernetes configuration file"
  value       = module.talos.kube_config
  sensitive   = true
}

output "talosconfig_path" {
  description = "Path to the talosconfig file (kept out of Terraform state; regenerate with `tofu apply`)."
  value       = module.talos.talosconfig_path
}
