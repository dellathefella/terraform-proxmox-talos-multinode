terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.0"
    }
  }
}

variable "pm_endpoint" {
  type        = string
  description = "Proxmox API endpoint (from CI repo variable PM_ENDPOINT)."
}

provider "proxmox" {
  endpoint = var.pm_endpoint
  # Credentials come from the PROXMOX_VE_API_TOKEN environment variable.
  ssh {
    agent    = true
    username = "root"
  }
}

module "talos" {
  source = "../../"

  cluster_name         = "ci-plan"
  network_gateway      = "10.0.0.1"
  lan_subnet           = "10.0.0.0/24"
  control_plane_subnet = "10.0.6.0/29"
  allowed_networks     = ["10.0.0.0/24"]

  control_plane_nodes = [
    { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" },
    { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" },
    { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" }
  ]

  node_pools = [
    {
      subnet    = "10.0.6.8/29"
      node_name = "pve0"
      size      = 2
      node_pool_settings = {
        name           = "pool0"
        cores          = 4
        memory         = 8192
        datastore_id   = "local-lvm"
        disk_size      = 60
        network_bridge = "vmbr0"
      }
    }
  ]
}
