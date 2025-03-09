locals {
  listed_worker_nodes = flatten([
    for pool in var.node_pools :
    [
      for i in range(pool.size) :
      merge(pool.node_pool_settings, {
        node_name = pool.node_name
        i         = i
        ip        = cidrhost(pool.subnet, i)
      })
    ]
  ])

  mapped_worker_nodes = {
    for node in local.listed_worker_nodes : "${node.name}-${node.i}" => node
  }

}

resource "proxmox_virtual_environment_vm" "talos-worker" {
  depends_on = [
    proxmox_virtual_environment_vm.talos-master
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

# resource "proxmox_vm_qemu" "k3s-worker" {
#   depends_on = [
#     proxmox_vm_qemu.k3s-support,
#     proxmox_vm_qemu.k3s-master,
#   ]

#   

#   node_name = each.value.node_name
#   name        = "${var.cluster_name}-${each.key}"

#   clone = var.node_template

#   pool   = var.proxmox_resource_pool
#   onboot = true

#   cores   = each.value.cores
#   sockets = each.value.sockets
#   memory  = each.value.memory
#   scsihw  = "virtio-scsi-pci"
#   disks {
#     ide {
#       ide2 {
#         cloudinit {
#           storage = each.value.storage_id
#         }
#       }
#     }
#     # Boot disk
#     scsi {
#       scsi0 {
#         disk {
#           storage = each.value.storage_id
#           size    = each.value.disk_size
#         }
#       }
#       dynamic "scsi1" {
#         for_each = each.value.additonal_storage != null ? [each.value.additonal_storage] : []
#         content {
#           disk {
#             storage = scsi1.value.storage_id
#             size    = scsi1.value.disk_size
#           }
#         }
#       }
#     }
#   }

#   network {
#     bridge    = each.value.network_bridge
#     firewall  = true
#     link_down = false
#     model     = "virtio"
#     queues    = 0
#     rate      = 0
#     tag       = each.value.network_tag
#   }

#   lifecycle {
#     ignore_changes = [
#       ciuser,
#       sshkeys,
#       disks,
#       network,
#       hagroup,
#       hastate,
#     ]

#   }

#   os_type = "cloud-init"

#   ciuser = each.value.user

#   ipconfig0 = "ip=${each.value.ip}/${local.lan_subnet_cidr_bitnum},gw=${var.network_gateway}"

#   sshkeys = file(var.authorized_keys_file)

#   connection {
#     type        = "ssh"
#     user        = each.value.user
#     host        = each.value.ip
#     private_key = file(var.authorized_private_key_file)
#     agent       = false
#   }

#   provisioner "remote-exec" {
#     inline = ["sleep 5",
#       templatefile("${path.module}/scripts/install-k3s-server.sh.tftpl", {
#         mode                 = "agent"
#         tokens               = [random_password.k3s-server-token.result]
#         alt_names            = []
#         disable              = []
#         server_hosts         = ["https://${local.support_node_ip}:6443"]
#         node_taints          = each.value.taints
#         datastores           = []
#         http_proxy           = var.http_proxy
#         extra_storage_enable = each.value.additonal_storage != null ? true : false
#         # This is when initializing etcd for the first time. It is always false on worker nodes.
#         embedded_etcd_init = false
#       })
#     , "sleep 5"]
#   }
# }
