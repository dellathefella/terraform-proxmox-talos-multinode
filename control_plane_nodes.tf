locals {
  listed_control_plane_nodes = flatten([
    for i, master_node in var.control_plane_nodes : merge(master_node, {
      name = "${var.cluster_name}-control-plane-${i}"
      i    = i
      # Used to force replacement
    ip = cidrhost(var.control_plane_subnet, i + 1) })
  ])

  mapped_control_plane_nodes = {
    for node in local.listed_control_plane_nodes : "${node.name}" => node
  }

}

resource "proxmox_virtual_environment_vm" "talos_control_plane" {
  depends_on = [
    proxmox_virtual_environment_container.talos_support
  ]
  for_each    = local.mapped_control_plane_nodes
  name        = each.value.name
  description = "Control plane node for Talos Cluster - ${var.cluster_name}"
  tags        = ["terraform", "talos", "${var.cluster_name}", "k8s-control-plane-node"]

  node_name = each.value.node_name

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

