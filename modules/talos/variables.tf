variable "cluster_name" {
  type        = string
  description = "Name of the cluster."
}

variable "control_plane_nodes" {
  description = "Control plane nodes with pre-computed names and IPs."
  type = list(object({
    name                 = string,
    ip                   = string,
    install_disks        = list(string),
    extra_config_patches = optional(list(string), [])
  }))
}

variable "worker_nodes" {
  description = "Worker nodes with pre-computed names and IPs."
  type = list(object({
    name          = string,
    i             = number,
    ip            = string,
    taints        = list(string),
    install_disks = list(string),
    additional_storage = optional(object({
      datastore_id = string,
      disk_size    = number,
    }), null)
    extra_config_patches = optional(list(string), [])
  }))
}

variable "lb_ip" {
  type        = string
  description = "IP address of the cluster load balancer (API endpoint)."
}

variable "api_hostnames" {
  type        = list(string)
  description = "Alternative hostnames for the API server."
}

variable "control_plane_vm_ids" {
  type        = map(string)
  description = "Map of control plane node name to Proxmox VM ID (drives replacement of machine config applies)."
}

variable "worker_vm_ids" {
  type        = map(string)
  description = "Map of '<pool-name>-<index>' to Proxmox VM ID (drives replacement of machine config applies)."
}
