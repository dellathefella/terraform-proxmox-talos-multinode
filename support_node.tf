locals {
  support_node_settings = var.support_node_settings
  support_node_ip       = cidrhost(var.control_plane_subnet, 0)
}

locals {
  lan_subnet_cidr_bitnum = split("/", var.lan_subnet)[1]
}


resource "proxmox_virtual_environment_download_file" "latest_ubuntu_24_noble_qcow2_img" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = length(var.proxmox_support_node) == 0 ? var.proxmox_node : var.proxmox_support_node
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}



resource "proxmox_virtual_environment_vm" "talos-support" {
  name        = join("-", [var.cluster_name, "support"])
  description = "Support node for Talos Cluster - ${join("-", [var.cluster_name, "support"])}"
  tags        = ["terraform", "ubuntu", "${var.cluster_name}","support"]

  node_name = length(var.proxmox_support_node) == 0 ? var.proxmox_node : var.proxmox_support_node

  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

  cpu {
    cores = local.support_node_settings.cores
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = local.support_node_settings.memory
    floating  = local.support_node_settings.memory # set equal to dedicated to enable ballooning
  }

  disk {
    datastore_id = local.support_node_settings.datastore_id
    file_id      = proxmox_virtual_environment_download_file.latest_ubuntu_24_noble_qcow2_img.id
    interface    = "virtio0"
    size         = local.support_node_settings.disk_size
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.support_node_ip}/${local.lan_subnet_cidr_bitnum}"
        gateway = var.network_gateway
      }
    }

    user_account {
      keys     = [trimspace(file(var.authorized_keys_file))]
      username = local.support_node_settings.user
    }

  }

  network_device {
    bridge = local.support_node_settings.network_bridge
  }

  operating_system {
    type = "l26"
  }

  tpm_state {
    version = "v2.0"
  }

  connection {
    type        = "ssh"
    user        = local.support_node_settings.user
    host        = local.support_node_ip
    private_key = file(var.authorized_private_key_file)
  }

  provisioner "file" {
    destination = "/tmp/install.sh"
    content = templatefile("${path.module}/scripts/install-support-apps.sh.tftpl", {
      http_proxy     = var.http_proxy
      ubuntu_version = var.ubuntu_version
    })
  }

  provisioner "remote-exec" {
    inline = [
      "chmod u+x /tmp/install.sh",
      "sh /tmp/install.sh",
      "rm -r /tmp/install.sh",
    ]
  }
}

resource "random_password" "support-user-password" {
  length           = 16
  special          = false
  override_special = "_%@"
}

resource "null_resource" "talos_nginx_config" {

  depends_on = [
    proxmox_virtual_environment_vm.talos-support
  ]

  triggers = {
    config_change       = filemd5("${path.module}/config/nginx.conf.tftpl")
    master_nodes_change = "${length(local.listed_master_nodes)}"
    worker_nodes_change = "${length(local.listed_worker_nodes)}"
  }

  connection {
    type        = "ssh"
    user        = local.support_node_settings.user
    host        = local.support_node_ip
    private_key = file(var.authorized_private_key_file)
  }

  provisioner "file" {
    destination = "/tmp/nginx.conf"
    content = templatefile("${path.module}/config/nginx.conf.tftpl", {
      talos_server_hosts = [for master_node in local.listed_master_nodes :
        "${master_node.ip}:6443"
      ]
      talos_nodes = concat([for master_node in local.listed_master_nodes : master_node.ip], [for node in local.listed_worker_nodes : node.ip])
    })
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo systemctl restart nginx.service",
    ]
  }
}
