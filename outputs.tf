output "cluster_lb_vm_ip" {
  value = local.cluster_lb_vm_ip
}

output "cluster_lb_vm_user" {
  value = "ubuntu"
}

output "cluster_client_configuration" {
  value = data.talos_client_configuration.cluster_client_configuration.talos_config
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