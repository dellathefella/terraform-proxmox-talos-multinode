variable "cluster_name" {
  type        = string
  description = "Name of the cluster."
}

variable "lb_ip" {
  type        = string
  description = "IP address assigned to the load balancer LXC."
}

variable "lan_subnet_cidr_bitnum" {
  type        = string
  description = "CIDR bit number of the LAN subnet (e.g. '24')."
}

variable "network_gateway" {
  type        = string
  description = "IP address of the network gateway."
}

variable "settings" {
  description = "Load balancer LXC settings."
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
}

variable "control_plane_ips" {
  type        = list(string)
  description = "IP addresses of the control plane nodes."
}

variable "worker_ips" {
  type        = list(string)
  description = "IP addresses of the worker nodes."
}

variable "allowed_networks" {
  type        = list(string)
  description = "CIDR ranges allowed to reach the load balancer ports."
}

variable "http_proxy" {
  type        = string
  description = "HTTP(S) proxy URL used when installing packages."
}

variable "authorized_keys_file" {
  type        = string
  description = "Path to file containing public SSH keys."
}

variable "authorized_private_key_file" {
  type        = string
  description = "Path to file containing the private SSH key."
}

variable "ha_enabled" {
  type        = bool
  default     = false
  description = "Deploy the secondary LB instance with keepalived (VRRP)."
}

variable "vip" {
  type        = string
  default     = ""
  description = "Virtual (VRRP) IP address for the HA load balancer endpoint."
}

variable "secondary_ip" {
  type        = string
  default     = null
  description = "IP address of the secondary LB LXC (required when ha_enabled)."
}

variable "vrrp_router_id" {
  type        = number
  default     = 51
  description = "VRRP virtual router ID."
}

variable "secondary_node_name" {
  type        = string
  default     = null
  description = "Proxmox node for the secondary LB LXC. Defaults to the primary node."
}

variable "firewall_enabled" {
  type        = bool
  default     = false
  description = "Enable the Proxmox firewall on the LB LXC(s) with default-deny inbound."
}
