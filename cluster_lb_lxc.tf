locals {
  cluster_lb_vm_settings = var.cluster_lb_vm_settings
  cluster_lb_vm_ip       = cidrhost(var.control_plane_subnet, 0)
}

locals {
  lan_subnet_cidr_bitnum = split("/", var.lan_subnet)[1]
}

resource "proxmox_virtual_environment_file" "cluster_lb_meta_data_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.cluster_lb_vm_settings.node_name

  source_raw {
    data = <<-EOF
    #cloud-config
    local-hostname: ${var.cluster_name}-cluster-lb
    EOF

    file_name = "${var.cluster_name}-cluster-lb-meta-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_download_file" "latest_ubuntu_24_noble_qcow2_img" {
  content_type = "iso"
  datastore_id = "local"
  file_name    = "${var.cluster_name}-ubuntu-24.04-noble-server-cloudimg-amd64.img"
  node_name     = local.cluster_lb_vm_settings.node_name
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}


resource "proxmox_virtual_environment_vm" "cluster_lb" {
  description = "Support VM for Talos Cluster - ${var.cluster_name}-cluster-lb"
  tags        = ["terraform", "ubuntu", "${var.cluster_name}", "nginx", "vm"]
  name = "${var.cluster_name}-cluster-lb"
  node_name    = local.cluster_lb_vm_settings.node_name
  
  stop_on_destroy = true
  cpu {
    cores = local.cluster_lb_vm_settings.cores
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }
  
  agent {
    enabled = false
  }

  memory {
    dedicated = local.cluster_lb_vm_settings.memory
    floating = local.cluster_lb_vm_settings.memory
  }

  disk {
    file_id = proxmox_virtual_environment_download_file.latest_ubuntu_24_noble_qcow2_img.id
    datastore_id = local.cluster_lb_vm_settings.datastore_id
    size         = local.cluster_lb_vm_settings.disk_size
    interface = "virtio0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.cluster_lb_vm_ip}/${local.lan_subnet_cidr_bitnum}"
        gateway = var.network_gateway
      }
    }
    meta_data_file_id = proxmox_virtual_environment_file.cluster_lb_meta_data_cloud_config.id
    user_account {
      keys     = [trimspace(file(var.authorized_keys_file))]
      password = random_password.cluster_lb_vm_password.result
      username = "ubuntu"
    }

  }
  network_device {
    bridge = local.cluster_lb_vm_settings.network_bridge
  }

  operating_system {
    type = "l26"
  }

  tpm_state {
    version = "v2.0"
  }

}

resource "random_password" "cluster_lb_vm_password" {
  length           = 16
  special          = false
  override_special = "_%@"
}

resource "null_resource" "talos_nginx_install" {
  depends_on = [
    proxmox_virtual_environment_vm.cluster_lb
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = local.cluster_lb_vm_ip
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
    proxmox_virtual_environment_vm.cluster_lb,
    null_resource.talos_nginx_install
  ]

  triggers = {
    config_change       = filemd5("${path.module}/config/nginx.conf.tftpl")
    control_plane_nodes_change = "${length(local.listed_control_plane_nodes)}"
    nginx_worker_connections = "${local.cluster_lb_vm_settings.nginx_worker_connections}"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = local.cluster_lb_vm_ip
    private_key = file(var.authorized_private_key_file)
  }

  provisioner "file" {
    destination = "/tmp/nginx.conf"
    content = templatefile("${path.module}/config/nginx.conf.tftpl", {
      talos_control_plane_nodes = [for control_plane_node in local.listed_control_plane_nodes: control_plane_node.ip]
      nginx_worker_connections = local.cluster_lb_vm_settings.nginx_worker_connections
    })
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo systemctl restart nginx.service",
    ]
  }
}
