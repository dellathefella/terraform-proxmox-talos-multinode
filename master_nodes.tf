locals {
  listed_master_nodes = flatten([
    for i, master_node in var.master_nodes : merge(master_node, {
      name = "${var.cluster_name}-master-${i}"
      i    = i
      # Used to force replacement
    ip = cidrhost(var.control_plane_subnet, i + 1) })
  ])

  mapped_master_nodes = {
    for node in local.listed_master_nodes : "${node.name}" => node
  }

}

resource "proxmox_virtual_environment_vm" "talos-master" {
  depends_on = [
    proxmox_virtual_environment_vm.talos-support
  ]
  for_each    = local.mapped_master_nodes
  name        = each.value.name
  description = "Master node for Talos Cluster - ${var.cluster_name}"
  tags        = ["terraform", "talos", "${var.cluster_name}", "k8s-master-node"]

  node_name = each.value.node_name

  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

  agent {
    enabled = true
  }

  startup {
    up_delay   = "60"
    down_delay = "60"
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
    size         = each.value.disk_size
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

