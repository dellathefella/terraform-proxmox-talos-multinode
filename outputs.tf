output "support_lxc_ip" {
  value = local.support_lxc_ip
}

output "support_lxc_user" {
  value = "root"
}

output "talos_control_plane_ips" {
  value = [
    for control_plane in local.listed_control_plane_nodes : control_plane.ip
  ]
 }

output "kube_config" {
  description = "Kubernetes configuration file"
  value       = talos_cluster_kubeconfig.cluster_kubeconfig
  sensitive   = true
}