variable "authorized_keys_file" {
  description = "Path to file containing public SSH keys for remoting into nodes."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
variable "authorized_private_key_file" {
  description = "Path to file containing private SSH keys for remoting into nodes."
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "cluster_talos_version" {
  default = "v1.10.6"
  type    = string
}

variable "network_gateway" {
  description = "IP address of the network gateway."
  type        = string
  validation {
    # condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", var.network_gateway))
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$", var.network_gateway))
    error_message = "The network_gateway value must be a valid ip."
  }
}

variable "lan_subnet" {
  description = <<EOF
Subnet used by the LAN network. Note that only the bit count number at the end
is acutally used, and all other subnets provided are secondary subnets.
EOF
  type        = string
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", var.lan_subnet))
    error_message = "The lan_subnet value must be a valid cidr range."
  }
}

variable "control_plane_subnet" {
  description = <<EOF
EOF
  type        = string
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", var.control_plane_subnet))
    error_message = "The control_plane_subnet value must be a valid cidr range."
  }
}

variable "bgp" {
  description = "Used for node labels when setting up BGP forwarding with Cilium."
  default     = 65020
  type        = number
}

variable "cluster_ipv4_cidr_pool" {
  default = "10.1.0.0/16"
  type = string
}

variable "cluster_cilium_id" {
  default = 2
  type = number
}

variable "cluster_name" {
  default     = "talos"
  type        = string
  description = "Name of the cluster used for prefixing cluster components (ie nodes)."
}

variable "cluster_lb_vm_settings" {
  description = "Default settings values for cluster LB LXC"
  type = object({
    node_name                = string,
    cores                    = number,
    memory                   = number,
    datastore_id             = string,
    disk_size                = number,
    network_bridge           = string,
    nginx_worker_connections = optional(number, 65536)
  })
  default = {
    node_name                = "pve"
    cores                    = 2
    memory                   = 2048
    datastore_id             = "local-lvm"
    disk_size                = 16
    network_bridge           = "vmbr0"
    nginx_worker_connections = 65536
  }
}

variable "allows_scheduling_on_control_plane_nodes" {
  type    = bool
  default = false
}

variable "control_plane_nodes" {
  description = "Default settings values for control plane nodes"
  type = list(object({
    node_name         = string,
    cores             = number,
    memory            = number,
    datastore_id      = string,
    network_bridge    = string,
    install_disk_size = optional(number, 24)
    install_disk      = optional(string, "/dev/sda")
  }))
}


variable "node_pools" {
  description = "Node pool definitions for the cluster."
  type = list(object({
    size      = number,
    subnet    = string,
    node_name = string,
    node_pool_settings = object({
      name              = string,
      taints            = optional(list(string), []),
      cores             = number,
      memory            = number,
      datastore_id      = string,
      install_disk      = optional(string, "/dev/sda")
      install_disk_size = optional(number, 48)
      data_disk_size    = optional(number, 96)
      gpu               = optional(string)
      network_bridge    = string,
    })
  }))

}

variable "api_hostnames" {
  description = "Alternative hostnames for the API server."
  type        = list(string)
  default     = []
}

variable "http_proxy" {
  default     = ""
  type        = string
  description = "http_proxy"
}
