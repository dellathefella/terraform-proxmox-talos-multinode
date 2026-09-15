terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.0"
    }
  }
}


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


provider "proxmox" {
  # Authenticate via the PM_USER / PM_PASS or PM_API_TOKEN_ID / PM_API_TOKEN_SECRET environment variables
  endpoint = "https://10.0.5.0:8006/"

  # Verify the PVE TLS certificate instead of disabling verification.
  # Copy the CA from the PVE node: /etc/pve/pve-root-ca.pem
  tls_ca_certificate = file("pve-root-ca.pem")
  # Only fall back to `insecure = true` if you cannot obtain the CA certificate.

  ssh {
    agent       = true
    username    = "root"
    private_key = file(var.authorized_private_key_file)
  }
}

module "talos" {
  # tflint-ignore: terraform_module_pinned_source
  source                      = "git::https://github.com/dellathefella/terraform-proxmox-talos-multinode.git?ref=main"
  authorized_keys_file        = var.authorized_keys_file
  authorized_private_key_file = "~/.ssh/id_ed25519"

  #Support node if none specified installs onto entry point node
  network_gateway = "10.0.0.1"
  lan_subnet      = "10.0.0.0/8"
  cluster_name    = "jacobian-dev"
  # Enabling this setting disables the MariaDB support instance for the cluster.
  # The main advantage of enabling embedded etcd is the cluster no longer has a single point of failure. But can increase resource usage.

  # This LXC acts as a load balancer, endpoint and load balancer for the cluster API. Additional ports can be added if needed. 
  cluster_lb_lxc_settings = {
    node_name      = "pve0"
    cores          = 2
    memory         = 512
    datastore_id   = "jacobian-nvme"
    disk_size      = 2
    network_bridge = "vmbr0"
    # You can specify additional ports to be load balanced via Nginx.
    additional_lb_worker_node_ports        = [31000, 31001]
    additional_lb_control_plane_node_ports = [9443]
    nginx_worker_connections               = 65536
  }

  # LB LXC takes 10.0.6.1, control plane nodes get 10.0.6.2 - 10.0.6.4
  control_plane_subnet = "10.0.6.0/29"

  # These are not rolled as a pool but individually.
  control_plane_nodes = [
    {
      node_name      = "pve0"
      cores          = 4
      memory         = 4096
      datastore_id   = "jacobian-nvme"
      disk_size      = 16
      network_bridge = "vmbr0"
    },
    {
      node_name      = "pve0"
      cores          = 4
      memory         = 4096
      datastore_id   = "jacobian-nvme"
      disk_size      = 16
      network_bridge = "vmbr0"
    },
    {
      node_name      = "pve0"
      cores          = 4
      memory         = 4096
      datastore_id   = "jacobian-nvme"
      disk_size      = 16
      network_bridge = "vmbr0"
    }
  ]
  node_pools = [
    {
      # 10.0.6.9 - 10.0.6.11 (3 nodes; .8 is the network address)
      subnet    = "10.0.6.8/29"
      node_name = "pve0"
      size      = 3
      node_pool_settings = {
        name           = "pool0",
        cores          = 8
        memory         = 10240
        datastore_id   = "jacobian-nvme"
        disk_size      = 120
        network_bridge = "vmbr0"
      }
    },
    # {
    #   # 10.0.6.17 - 10.0.6.19 (3 nodes; .16 is the network address)
    #   subnet    = "10.0.6.16/29"
    #   node_name = "pve0"
    #   size      = 3
    #   node_pool_settings = {
    #     name           = "pool1",
    #     cores          = 8
    #     memory         = 10240
    #     datastore_id   = "jacobian-nvme"
    #     disk_size      = 120
    #     network_bridge = "vmbr0"
    #   }
    # },
    # {
    #   # 10.0.6.25 - 10.0.6.27 (3 nodes; .24 is the network address)
    #   subnet    = "10.0.6.24/29"
    #   node_name = "pve0"
    #   size      = 3
    #   node_pool_settings = {
    #     name           = "pool2",
    #     taints         = ["sometaint"]
    #     cores          = 8
    #     memory         = 10240
    #     datastore_id   = "jacobian-nvme"
    #     disk_size      = 120
    #     network_bridge = "vmbr0"
    #   }
    # }
  ]
}

output "kube_config" {
  # Update module name. Here we are using 'talos'
  value     = module.talos.kube_config
  sensitive = true
}