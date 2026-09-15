output "kube_config" {
  description = "Kubernetes configuration file."
  value       = talos_cluster_kubeconfig.cluster_kubeconfig.kubeconfig_raw
  sensitive   = true
}

output "talosconfig_path" {
  description = "Path to the talosconfig file written at plan time (kept out of Terraform state)."
  value       = local_file.talosconfig.filename
}

output "worker_health_check_passed" {
  description = "True once the post-join worker health check has passed."
  value       = length(data.talos_cluster_health.workers) > 0 ? data.talos_cluster_health.workers[0].id != null : false
}

