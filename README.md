# terraform-proxmox-talos-multi-node

A module for spinning up an expandable and flexible Talos server for your HomeLab in a multinode Proxmox cluster.

## Features
- Fully automated. No need to remote into a VM; even for a kubeconfig
- Built in and automatically configured external loadbalancer (both K8s API and ingress)
- Node pools to easily scale and to handle many kinds of workloads
- Master nodes with custom topology for your use cases.
- Pure Terraform - no Ansible needed.
- Support to add and automatically format additional storage for use with tools like Longhorn.

## Prerequisites
- Proxmox node(s) running 8.2 or higher
- Proxmox nodes with sufficient capacity for all nodes
- SSH Keys copied to nodes that will have Talos Cluster created. Needed for image downloads and conversion.
- At least 2 CIDR ranges for master and worker nodes NOT handed out by DHCP (All Nodes are configured with static IPs from these ranges)

## The BPG Provider does certain functions that require SSH on each Proxmox node your SSH private key will need to be copied.
```sh
# On deployer VM or system.
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@10.0.5.0
```



## Usage and Example

```terraform
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
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


provider "proxmox" {
  # make sure to export PM_API_TOKEN_ID and PM_API_TOKEN_SECRET
  insecure = true
  endpoint = "https://10.0.5.0:8006/"
  password = "REDACTED"
  username = "root@pam"
  ssh {
    agent       = true
    username    = "root"
    private_key = file(var.authorized_private_key_file)
  }
}

module "talos" {
  source                      = "git::github.com/dellathefella/terraform-proxmox-talos-multinode"
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
    node_name = "pve0"
    cores          = 2
    memory         = 512
    datastore_id   = "jacobian-nvme"
    disk_size      = 2
    network_bridge = "vmbr0"
    # You can specify additional ports to be load balanced via Nginx.
    additional_lb_worker_node_ports = [31000,31001]
    additional_lb_control_plane_node_ports = [9443]
    nginx_worker_connections = 65536
  }

  # 10.0.6.1 - 10.0.6.6	(5 available IPs for nodes)
  control_plane_subnet = "10.0.6.1/29"

  # These are not rolled as a pool but individually.
  control_plane_nodes = [
    {
      node_name    = "pve0"
      cores        = 4
      memory       = 4096
      datastore_id = "jacobian-nvme"
      disk_size      = 16
      network_bridge = "vmbr0"
    },
    {
      node_name    = "pve0"
      cores        = 4
      memory       = 4096
      datastore_id = "jacobian-nvme"
      disk_size      = 16
      network_bridge = "vmbr0"
    },
    {
      node_name    = "pve0"
      cores        = 4
      memory       = 4096
      datastore_id = "jacobian-nvme"
      disk_size      = 16
      network_bridge = "vmbr0"
    }
  ]
  node_pools = [
    {
      # 10.0.6.9 - 10.0.6.14 (5 available IPs for nodes)
      subnet    = "10.0.6.8/29"
      node_name = "pve0"
      size      = 3
      node_pool_settings = {
        name           = "pool0",
        cores          = 8
        sockets        = 1
        memory         = 10240
        storage_type   = "scsi"
        datastore_id   = "jacobian-nvme"
        disk_size      = 120
        network_bridge = "vmbr0"
      }
    },
    # {

    #   # 10.0.6.17 - 10.0.6.22	 (6 available IPs for nodes)
    #   subnet    = "10.0.6.16/29"
    #   node_name = "pve0"
    #   size      = 3
    #   node_pool_settings = {
    #     name           = "pool1",
    #     cores          = 8
    #     sockets        = 1
    #     memory         = 10240
    #     storage_type   = "scsi"
    #     datastore_id   = "jacobian-nvme"
    #     disk_size      = 120
    #     network_bridge = "vmbr0"
    #   },
    # },
    # {
    #   # 10.0.6.25 - 10.0.6.30 (6 available IPs for nodes)
    #   subnet = "10.0.6.24/29"

    #   node_name = "pve0"
    #   size      = 3
    #   node_pool_settings = {
    #     name           = "pool2",
    #     taints         = ["sometaint"]
    #     cores          = 8
    #     sockets        = 1
    #     memory         = 10240
    #     storage_type   = "scsi"
    #     datastore_id   = "jacobian-nvme"
    #     disk_size      = 120
    #     network_bridge = "vmbr0"
    #   }
    # }
  ]
}

output "kube_config" {
  # Update module name. Here we are using 'Talos'
  value     = module.talos.kube_config.kubeconfig_raw
  sensitive = true
}
```

Finally output the config file:

```sh
# Test out the config:
terraform output -raw kube_config > config.yaml && kubectl --kubeconfig config.yaml get nodes
kubectl --kubeconfig config.yaml get nodes
```


> Make sure your support node is routable from the computer you are running the command on!

## Runbooks

- [How to roll (update) your nodes](docs/roll-node-pools.md)

## Why use nodepools and subnets?

This module is designed with nodepools and subnets to allow for changes to the
cluster composition in the future. If later on, you want to add another master
or worker node, you can do so without needing to teardown/modify existing
nodes. Nodepools are key if you plan to support nodes with different nodepool
capabilities in the future without impacting other nodes.