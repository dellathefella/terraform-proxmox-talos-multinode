variable "cluster_name" {
  type        = string
  description = "Name of the cluster."
}

variable "nodes" {
  description = "Worker nodes with pre-computed names and IPs."
  type = list(object({
    name           = string,
    node_name      = string,
    i              = number,
    ip             = string,
    taints         = list(string),
    cores          = number,
    memory         = number,
    datastore_id   = string,
    install_disks  = list(string),
    disk_size      = number,
    network_bridge = string,
    additional_storage = optional(object({
      datastore_id = string,
      disk_size    = number,
    }), null)
  }))
}

variable "network_gateway" {
  type        = string
  description = "IP address of the network gateway."
}

variable "lan_subnet_cidr_bitnum" {
  type        = string
  description = "CIDR bit number of the LAN subnet (e.g. '24')."
}

variable "talos_image_ids" {
  type        = map(string)
  description = "Map of Proxmox node name to Talos image file ID."
}
