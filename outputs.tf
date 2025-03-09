output "support_node_ip" {
  value = local.support_node_ip
}

output "support_node_user" {
  value = local.support_node_settings.user
}

output "talos_master_node_ips" {
  value = [
    for master_node in local.listed_master_nodes : master_node.ip
  ]
}

output "kube_config" {
  description = "Kubernetes configuration file"
  value       = talos_cluster_kubeconfig.cluster_kubeconfig
  sensitive   = true
}