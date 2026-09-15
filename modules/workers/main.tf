resource "proxmox_virtual_environment_vm" "vm" {
  for_each    = { for node in var.nodes : "${node.name}-${node.i}" => node }
  name        = "${var.cluster_name}-${each.value.name}-${each.value.i}"
  description = "Worker node for Talos Cluster - ${var.cluster_name}"
  tags        = ["terraform", "talos", var.cluster_name, "k8s-worker-node"]

  node_name = each.value.node_name

  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true
  on_boot         = true

  startup {
    order      = 3
    up_delay   = 30
    down_delay = 30
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = each.value.memory
    floating  = each.value.memory # set equal to dedicated to disable ballooning
  }

  disk {
    datastore_id = each.value.datastore_id
    file_id      = var.talos_image_ids[each.value.node_name]
    interface    = "virtio0"
    size         = each.value.disk_size
  }

  dynamic "disk" {
    for_each = each.value.additional_storage != null ? [each.value.additional_storage] : []
    content {
      datastore_id = disk.value.datastore_id
      interface    = "virtio1"
      size         = disk.value.disk_size
    }
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.lan_subnet_cidr_bitnum}"
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
