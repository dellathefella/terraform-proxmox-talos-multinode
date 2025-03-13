locals {
  cluster_lb_lxc_settings = var.cluster_lb_lxc_settings
  cluster_lb_lxc_ip       = cidrhost(var.control_plane_subnet, 0)
}

locals {
  lan_subnet_cidr_bitnum = split("/", var.lan_subnet)[1]
}


resource "proxmox_virtual_environment_download_file" "latest_ubuntu_24_noble_lxc_img" {
  content_type = "vztmpl"
  datastore_id = "local"
  file_name    = "${var.cluster_name}-ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  node_name    = local.cluster_lb_lxc_settings.node_name
  url          = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
}



resource "proxmox_virtual_environment_container" "cluster_lb" {
  description = "Support LXC for Talos Cluster - ${var.cluster_name}-cluster-lb"
  tags        = ["terraform", "ubuntu", "${var.cluster_name}", "nginx", "lxc"]

  node_name    = local.cluster_lb_lxc_settings.node_name
  unprivileged = true
  cpu {
    cores = local.cluster_lb_lxc_settings.cores
  }

  memory {
    dedicated = local.cluster_lb_lxc_settings.memory
    swap      = local.cluster_lb_lxc_settings.memory / 2
  }

  disk {
    datastore_id = local.cluster_lb_lxc_settings.datastore_id
    size         = local.cluster_lb_lxc_settings.disk_size
  }

  initialization {
    hostname = "${var.cluster_name}-cluster-lb"
    ip_config {
      ipv4 {
        address = "${local.cluster_lb_lxc_ip}/${local.lan_subnet_cidr_bitnum}"
        gateway = var.network_gateway
      }
    }

    user_account {
      keys     = [trimspace(file(var.authorized_keys_file))]
      password = random_password.cluster_lb_lxc_password.result
    }

  }

  network_interface {
    name = local.cluster_lb_lxc_settings.network_bridge
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.latest_ubuntu_24_noble_lxc_img.id
    type             = "ubuntu"
  }

  features {
    nesting = true
  }




}

resource "random_password" "cluster_lb_lxc_password" {
  length           = 16
  special          = false
  override_special = "_%@"
}

resource "null_resource" "talos_nginx_install" {
  depends_on = [
    proxmox_virtual_environment_container.cluster_lb
  ]

  connection {
    type        = "ssh"
    user        = "root"
    host        = local.cluster_lb_lxc_ip
    private_key = file(var.authorized_private_key_file)
  }

  provisioner "file" {
    destination = "/tmp/install.sh"
    content = templatefile("${path.module}/scripts/install-support-nginx.sh.tftpl", {
      http_proxy = var.http_proxy
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

resource "null_resource" "talos_nginx_config" {

  depends_on = [
    proxmox_virtual_environment_container.cluster_lb,
    null_resource.talos_nginx_install
  ]

  triggers = {
    config_change       = filemd5("${path.module}/config/nginx.conf.tftpl")
    control_plane_nodes_change = "${length(local.listed_control_plane_nodes)}"
    worker_nodes_change = "${length(local.listed_worker_nodes)}"
    additional_lb_worker_node_ports = "${length(local.cluster_lb_lxc_settings.additional_lb_worker_node_ports)}"
    additional_lb_control_plane_node_ports = "${length(local.cluster_lb_lxc_settings.additional_lb_control_plane_node_ports)}"
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = local.cluster_lb_lxc_ip
    private_key = file(var.authorized_private_key_file)
  }

  provisioner "file" {
    destination = "/tmp/nginx.conf"
    content = templatefile("${path.module}/config/nginx.conf.tftpl", {
      talos_control_plane_nodes = [for control_plane_node in local.listed_control_plane_nodes: control_plane_node.ip]
      additional_lb_worker_node_ports = local.cluster_lb_lxc_settings.additional_lb_worker_node_ports
      additional_lb_control_plane_node_ports = local.cluster_lb_lxc_settings.additional_lb_control_plane_node_ports
      talos_nodes = concat([for control_plane in local.listed_control_plane_nodes : control_plane.ip], [for worker_node in local.listed_worker_nodes : worker_node.ip])
    })
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo systemctl restart nginx.service",
    ]
  }
}
