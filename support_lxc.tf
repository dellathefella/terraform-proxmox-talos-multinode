locals {
  support_lxc_settings = var.support_lxc_settings
  support_lxc_ip       = cidrhost(var.control_plane_subnet, 0)
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



resource "proxmox_virtual_environment_vm" "talos_support" {
  description = "Support LXC for Talos Cluster - ${join("-", [var.cluster_name, "support"])}"
  tags        = ["terraform", "ubuntu", "${var.cluster_name}","support","lxc"]

  node_name = support_lxc_settings.node_name

  cpu {
    cores = local.support_lxc_settings.cores
  }

  memory {
    dedicated = local.support_lxc_settings.memory
    swap  = local.support_lxc_settings.memory/2
  }

  disk {
    datastore_id = local.support_lxc_settings.datastore_id
    size         = local.support_lxc_settings.disk_size
  }

  initialization {
    hostname = "${var.cluster_name}-support"
    ip_config {
      ipv4 {
        address = "${local.support_lxc_ip}/${local.lan_subnet_cidr_bitnum}"
        gateway = var.network_gateway
      }
    }

    user_account {
      keys     = [trimspace(file(var.authorized_keys_file))]
      password = random_password.support_lxc_password.result
    }

  }

  network_interface  {
    name = local.support_lxc_settings.network_bridge
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = local.support_lxc_ip
    private_key = file(var.authorized_private_key_file)
  }
  
  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.latest_ubuntu_22_jammy_lxc_img.id
    # Or you can use a volume ID, as obtained from a "pvesm list <storage>"
    # template_file_id = "local:vztmpl/jammy-server-cloudimg-amd64.tar.gz"
    type             = "ubuntu"
  }

  features {
    nesting = true
  }

  provisioner "file" {
    destination = "/tmp/install.sh"
    content = templatefile("${path.module}/scripts/install-support-apps.sh.tftpl", {
      http_proxy     = var.http_proxy
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

resource "random_password" "support_lxc_password" {
  length           = 16
  special          = false
  override_special = "_%@"
}

resource "null_resource" "talos_nginx_config" {

  depends_on = [
    proxmox_virtual_environment_vm.talos_support
  ]

  triggers = {
    config_change       = filemd5("${path.module}/config/nginx.conf.tftpl")
    master_nodes_change = "${length(local.listed_master_nodes)}"
    worker_nodes_change = "${length(local.listed_worker_nodes)}"
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = local.support_lxc_ip
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
