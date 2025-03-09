variable "proxmox_node" {
  description = "Proxmox node to create VMs on."
  type        = string
  default     = ""
}
variable "proxmox_support_node" {
  description = "Proxmox node to create VMs on."
  type        = string
  default     = ""
}

variable "ubuntu_version" {
  description = "Ubuntu version; an additional dependency needs to be installed for NGINX to work correctly in Ubuntu 24.04"
  type        = number
  default     = 24
}

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

variable "cluster_name" {
  default     = "k3s"
  type        = string
  description = "Name of the cluster used for prefixing cluster components (ie nodes)."
}

variable "support_node_template" {
  type        = string
  description = <<EOF
Proxmox vm to use as a base template for all nodes. Can be a template or
another vm that supports cloud-init.
EOF
}

variable "proxmox_resource_pool" {
  description = "Resource pool name to use in proxmox to better organize nodes."
  type        = string
  default     = ""
}

variable "support_node_settings" {
  description = "Default settings values for support nodes"
  type = object({
    cores          = number,
    sockets        = number,
    memory         = number,
    datastore_id   = string,
    disk_size      = number,
    user           = string,
    network_bridge = string,
  })
  default = {
    cores          = 2
    sockets        = 1
    memory         = 4096
    datastore_id   = "local-lvm"
    disk_size      = 10
    user           = "support"
    network_bridge = "vmbr0"
  }
}
variable "master_nodes" {
  description = "Default settings values for master nodes"
  type = list(object({
    node_name      = string,
    cores          = number,
    memory         = number,
    datastore_id   = string,
    disk_size      = string,
    network_bridge = string,
    install_disk   = optional(string, "/dev/sda")
  }))
}


variable "node_pools" {
  description = "Node pool definitions for the cluster."
  type = list(object({
    size      = number,
    subnet    = string,
    node_name = string,
    node_pool_settings = object({
      name           = string,
      taints         = optional(list(string)),
      cores          = number,
      memory         = number,
      datastore_id   = string,
      install_disk   = optional(string, "/dev/sda")
      disk_size      = string,
      network_bridge = string,
      additonal_storage = optional(object({
        datastore_id = string,
        disk_size    = string,
      }), null)
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
