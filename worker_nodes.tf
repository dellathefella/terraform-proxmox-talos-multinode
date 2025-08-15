locals {
  listed_worker_nodes = flatten([
    for pool in var.node_pools :
    [
      for i in range(pool.size) :
      merge(pool.node_pool_settings, {
        nodepool_name = pool.node_pool_settings.name
        node_name     = pool.node_name
        i             = i
        ip            = cidrhost(pool.subnet, i)
      })
    ]
  ])

  mapped_worker_nodes = {
    for node in local.listed_worker_nodes : "${node.name}-${node.i}" => node
  }

}

resource "proxmox_virtual_environment_vm" "talos_worker" {
  depends_on = [
    proxmox_virtual_environment_vm.talos_control_plane
  ]
  for_each    = local.mapped_worker_nodes
  description = "Worker node for Talos Cluster - ${var.cluster_name}"
  tags        = ["terraform", "talos", "${var.cluster_name}", "k8s-worker-node"]
  name        = "${var.cluster_name}-${each.value.name}-${each.value.i}"
  node_name   = each.value.node_name

  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = each.value.memory
    floating  = each.value.memory # set equal to dedicated to enable ballooning
  }

  disk {
    datastore_id = each.value.datastore_id
    file_id      = proxmox_virtual_environment_download_file.talos_image[each.value.node_name].id
    interface    = "virtio0"
    size         = each.value.install_disk_size
  }

  disk {
    datastore_id = each.value.datastore_id
    interface    = "virtio1"
    size         = each.value.data_disk_size
    file_format  = "raw"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${local.lan_subnet_cidr_bitnum}"
        gateway = var.network_gateway
      }
    }
  }

  network_device {
    bridge = each.value.network_bridge
  }

  operating_system {
    type = "l26"
  }

  tpm_state {
    version = "v2.0"
  }
}
