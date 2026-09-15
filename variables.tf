variable "authorized_keys_file" {
  description = "Path to file containing public SSH keys for remoting into nodes."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
variable "authorized_private_key_file" {
  description = "Path to file containing private SSH keys for remoting into nodes."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "network_gateway" {
  description = "IP address of the network gateway."
  type        = string
  validation {
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
  description = "CIDR range used for the cluster LB LXC (.1) and control plane nodes (.2+). The network address (.0) is never assigned."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", var.control_plane_subnet))
    error_message = "The control_plane_subnet value must be a valid cidr range."
  }
}

variable "cluster_name" {
  default     = "talos"
  type        = string
  description = "Name of the cluster used for prefixing cluster components (ie nodes)."
}

variable "cluster_lb_lxc_settings" {
  description = "Default settings values for cluster LB LXC"
  type = object({
    node_name                              = string,
    cores                                  = number,
    memory                                 = number,
    datastore_id                           = string,
    disk_size                              = number,
    network_bridge                         = string,
    additional_lb_worker_node_ports        = optional(list(number), [])
    additional_lb_control_plane_node_ports = optional(list(number), [])
    nginx_worker_connections               = optional(number, 768)
  })
  default = {
    node_name                              = "pve"
    cores                                  = 2
    memory                                 = 512
    datastore_id                           = "local-lvm"
    disk_size                              = 4
    network_bridge                         = "vmbr0"
    nginx_worker_connections               = 768
    additional_lb_worker_node_ports        = []
    additional_lb_control_plane_node_ports = []
  }
}

variable "control_plane_nodes" {
  description = "Control plane nodes. Use an odd count (1, 3, 5) for etcd quorum."
  type = list(object({
    node_name            = string,
    cores                = number,
    memory               = number,
    datastore_id         = string,
    disk_size            = number,
    network_bridge       = string,
    install_disks        = optional(list(string), ["/dev/sda"])
    extra_config_patches = optional(list(string), [])
  }))

  validation {
    condition     = length(var.control_plane_nodes) > 0
    error_message = "At least one control plane node is required."
  }

  validation {
    condition     = length(var.control_plane_nodes) % 2 == 1
    error_message = "control_plane_nodes should be an odd number (1, 3, 5) for etcd quorum."
  }
}

check "control_plane_node_spread" {
  assert {
    condition     = length(var.control_plane_nodes) < 2 || length(toset([for n in var.control_plane_nodes : n.node_name])) > 1
    error_message = "All control plane nodes are on the same Proxmox node. A single node failure takes down the entire control plane and the etcd quorum - spread them across nodes."
  }
}

variable "node_pools" {
  description = "Node pool definitions for the cluster."
  type = list(object({
    size      = number,
    subnet    = string,
    node_name = string,
    node_pool_settings = object({
      name           = string,
      taints         = optional(list(string), []),
      cores          = number,
      memory         = number,
      datastore_id   = string,
      install_disks  = optional(list(string), ["/dev/sda"])
      disk_size      = number,
      network_bridge = string,
      additional_storage = optional(object({
        datastore_id = string,
        disk_size    = number,
      }), null)
      extra_config_patches = optional(list(string), [])
    })
  }))

  validation {
    condition     = length(var.node_pools) == length({ for pool in var.node_pools : pool.node_pool_settings.name => true... })
    error_message = "Node pool names must be unique."
  }

  validation {
    condition = alltrue([
      for pool in var.node_pools :
      pool.size <= pow(2, 32 - tonumber(split("/", pool.subnet)[1])) - 2
    ])
    error_message = "Each node pool subnet must have enough usable host addresses for its size."
  }
}

variable "lb_ha_enabled" {
  description = "Deploy a second load balancer LXC with keepalived (VRRP) so the cluster API endpoint survives a single LB failure. The secondary LB takes .2 of control_plane_subnet and control plane nodes shift to .3+."
  type        = bool
  default     = false
}

variable "lb_vip" {
  description = "Virtual (VRRP) IP address for the highly available load balancer endpoint. Required when lb_ha_enabled is true; must be a free address on the LAN."
  type        = string
  default     = ""
}

check "lb_ha_vip_required" {
  assert {
    condition     = !var.lb_ha_enabled || can(cidrhost("${var.lb_vip}/32", 0))
    error_message = "lb_vip must be a valid IPv4 address when lb_ha_enabled is true."
  }
}

variable "lb_vrrp_router_id" {
  description = "VRRP virtual router ID for the HA load balancer. Must be unique per L2 segment."
  type        = number
  default     = 51
}

variable "lb_secondary_node_name" {
  description = "Proxmox node for the secondary LB LXC. Defaults to the primary LB node."
  type        = string
  default     = null
}

check "lb_ha_secondary_node_separation" {
  assert {
    condition = !var.lb_ha_enabled || (
      var.lb_secondary_node_name != null &&
      var.lb_secondary_node_name != var.cluster_lb_lxc_settings.node_name
    )
    error_message = "lb_ha_enabled is true but the secondary LB is not on a separate Proxmox node. Set lb_secondary_node_name to a different node than cluster_lb_lxc_settings.node_name, otherwise both LB instances die together with the node and HA provides no node-level protection."
  }
}

variable "lb_firewall_enabled" {
  description = "Enable the Proxmox firewall on the load balancer LXC(s): default-deny inbound with only allowed_networks permitted."
  type        = bool
  default     = false
}

variable "allowed_networks" {
  description = "CIDR ranges allowed to reach the cluster load balancer ports (6443, 80, 443, 50000/50001 and any additional ports)."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for n in var.allowed_networks : can(cidrhost(n, 0))])
    error_message = "Each entry in allowed_networks must be a valid CIDR range."
  }
}

variable "api_hostnames" {
  description = "Alternative hostnames for the API server."
  type        = list(string)
  default     = []
}

variable "talos_version" {
  description = "Talos version to install (must be available on the Talos Image Factory)."
  type        = string
  default     = "v1.14.1"
  validation {
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+$", var.talos_version))
    error_message = "talos_version must be in the form vX.Y.Z (e.g. v1.14.1)."
  }
}

variable "talos_arch" {
  description = "CPU architecture of the Talos images (amd64 or arm64)."
  type        = string
  default     = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.talos_arch)
    error_message = "talos_arch must be 'amd64' or 'arm64'."
  }
}

variable "http_proxy" {
  default     = ""
  type        = string
  description = "HTTP(S) proxy URL used when installing packages on the load balancer LXC."
}

variable "create_pve_pool" {
  description = "Create a Proxmox pool named after the cluster and add all cluster VMs/LXCs to it (UI grouping, ACLs, backup scoping)."
  type        = bool
  default     = true
}

variable "pbs_datastore_id" {
  description = "Proxmox Backup Server datastore ID. When set, a nightly backup job for the cluster pool is created."
  type        = string
  default     = null
}

variable "backup_schedule" {
  description = "Backup schedule in systemd calendar-event format (requires pbs_datastore_id)."
  type        = string
  default     = "*-*-* 03:00"
}
