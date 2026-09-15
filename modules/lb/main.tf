locals {
  lb_instances = merge(
    {
      primary = {
        ip       = var.lb_ip
        node     = var.settings.node_name
        state    = "MASTER"
        priority = 100
      }
    },
    var.ha_enabled ? {
      secondary = {
        ip       = var.secondary_ip
        node     = coalesce(var.secondary_node_name, var.settings.node_name)
        state    = "BACKUP"
        priority = 90
      }
    } : {}
  )

  lb_nodes = toset([for instance in local.lb_instances : instance.node])

  lb_ports = concat(
    [6443, 80, 443, 50000, 50001],
    var.settings.additional_lb_worker_node_ports,
    var.settings.additional_lb_control_plane_node_ports
  )

  lb_firewall_rule_map = {
    for idx, pair in setproduct(var.allowed_networks, local.lb_ports) :
    tostring(idx) => {
      source = pair[0]
      dport  = tostring(pair[1])
    }
  }
}

resource "proxmox_download_file" "latest_ubuntu_24_noble_lxc_img" {
  for_each = local.lb_nodes

  content_type = "vztmpl"
  datastore_id = "local"
  file_name    = "${var.cluster_name}-ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  node_name    = each.key
  url          = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
}

resource "random_password" "cluster_lb_lxc_password" {
  length  = 16
  special = false
}

# VRRP passwords are truncated to 8 characters by the protocol.
resource "random_password" "vrrp_auth" {
  length  = 8
  special = false
}

resource "proxmox_virtual_environment_container" "cluster_lb" {
  for_each = local.lb_instances

  description = "Support LXC for Talos Cluster - ${var.cluster_name}-cluster-lb-${each.key}"
  tags        = ["terraform", "ubuntu", var.cluster_name, "nginx", "lxc"]

  node_name     = each.value.node
  unprivileged  = true
  start_on_boot = true

  startup {
    order      = 1
    up_delay   = 30
    down_delay = 30
  }

  cpu {
    cores = var.settings.cores
  }

  memory {
    dedicated = var.settings.memory
    swap      = var.settings.memory / 2
  }

  disk {
    datastore_id = var.settings.datastore_id
    size         = var.settings.disk_size
  }

  initialization {
    hostname = each.key == "primary" ? "${var.cluster_name}-cluster-lb" : "${var.cluster_name}-cluster-lb-${each.key}"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.lan_subnet_cidr_bitnum}"
        gateway = var.network_gateway
      }
    }

    user_account {
      keys     = [trimspace(file(pathexpand(var.authorized_keys_file)))]
      password = random_password.cluster_lb_lxc_password.result
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.settings.network_bridge
  }

  operating_system {
    template_file_id = proxmox_download_file.latest_ubuntu_24_noble_lxc_img[each.value.node].id
    type             = "ubuntu"
  }

  features {
    nesting = true
  }
}

resource "null_resource" "talos_nginx_install" {
  for_each = local.lb_instances

  depends_on = [
    proxmox_virtual_environment_container.cluster_lb
  ]

  triggers = {
    script_change = filemd5("${path.root}/scripts/install-support-nginx.sh.tftpl")
    http_proxy    = var.http_proxy
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = each.value.ip
    private_key = file(pathexpand(var.authorized_private_key_file))
  }

  provisioner "file" {
    destination = "/tmp/install.sh"
    content = templatefile("${path.root}/scripts/install-support-nginx.sh.tftpl", {
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
  for_each = local.lb_instances

  depends_on = [
    proxmox_virtual_environment_container.cluster_lb,
    null_resource.talos_nginx_install
  ]

  triggers = {
    config_change                          = filemd5("${path.root}/config/nginx.conf.tftpl")
    control_plane_nodes_change             = sha256(join(",", var.control_plane_ips))
    worker_nodes_change                    = sha256(join(",", var.worker_ips))
    additional_lb_worker_node_ports        = join(",", [for port in var.settings.additional_lb_worker_node_ports : tostring(port)])
    additional_lb_control_plane_node_ports = join(",", [for port in var.settings.additional_lb_control_plane_node_ports : tostring(port)])
    nginx_worker_connections               = tostring(var.settings.nginx_worker_connections)
    allowed_networks                       = join(",", var.allowed_networks)
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = each.value.ip
    private_key = file(pathexpand(var.authorized_private_key_file))
  }

  provisioner "file" {
    destination = "/tmp/nginx.conf"
    content = templatefile("${path.root}/config/nginx.conf.tftpl", {
      talos_control_plane_nodes              = var.control_plane_ips
      talos_nodes                            = concat(var.control_plane_ips, var.worker_ips)
      additional_lb_worker_node_ports        = var.settings.additional_lb_worker_node_ports
      additional_lb_control_plane_node_ports = var.settings.additional_lb_control_plane_node_ports
      nginx_worker_connections               = var.settings.nginx_worker_connections
      allowed_networks                       = var.allowed_networks
    })
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo systemctl restart nginx.service",
    ]
  }
}

resource "null_resource" "keepalived_install" {
  for_each = var.ha_enabled ? local.lb_instances : {}

  depends_on = [
    null_resource.talos_nginx_install
  ]

  triggers = {
    ha_enabled = tostring(var.ha_enabled)
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = each.value.ip
    private_key = file(pathexpand(var.authorized_private_key_file))
  }

  provisioner "file" {
    destination = "/tmp/keepalived-install.sh"
    content     = <<-EOT
      #!/bin/bash
      export HTTP_PROXY="${var.http_proxy}"
      export HTTPS_PROXY="${var.http_proxy}"
      DEBIAN_FRONTEND=noninteractive apt-get update &&
      DEBIAN_FRONTEND=noninteractive apt-get install -y keepalived
    EOT
  }

  provisioner "remote-exec" {
    inline = [
      "chmod u+x /tmp/keepalived-install.sh",
      "sh /tmp/keepalived-install.sh",
      "rm -f /tmp/keepalived-install.sh",
    ]
  }
}

resource "null_resource" "keepalived_config" {
  for_each = var.ha_enabled ? local.lb_instances : {}

  depends_on = [
    null_resource.keepalived_install
  ]

  triggers = {
    config_change = filemd5("${path.root}/config/keepalived.conf.tftpl")
    vip           = var.vip
    router_id     = tostring(var.vrrp_router_id)
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = each.value.ip
    private_key = file(pathexpand(var.authorized_private_key_file))
  }

  provisioner "file" {
    destination = "/tmp/keepalived.conf"
    content = templatefile("${path.root}/config/keepalived.conf.tftpl", {
      state     = each.value.state
      priority  = each.value.priority
      router_id = var.vrrp_router_id
      vip       = var.vip
      node_ip   = each.value.ip
      auth_pass = random_password.vrrp_auth.result
      peer_ip   = each.value.state == "MASTER" ? var.secondary_ip : var.lb_ip
    })
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/keepalived.conf /etc/keepalived/keepalived.conf",
      "sudo systemctl enable --now keepalived.service",
      "sudo systemctl restart keepalived.service",
    ]
  }
}

resource "proxmox_virtual_environment_firewall_options" "lb" {
  for_each = var.firewall_enabled ? local.lb_instances : {}

  node_name    = each.value.node
  container_id = proxmox_virtual_environment_container.cluster_lb[each.key].vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_rules" "lb" {
  for_each = var.firewall_enabled ? local.lb_instances : {}

  node_name    = each.value.node
  container_id = proxmox_virtual_environment_container.cluster_lb[each.key].vm_id

  dynamic "rule" {
    for_each = local.lb_firewall_rule_map
    content {
      action  = "ACCEPT"
      type    = "in"
      source  = rule.value.source
      dport   = rule.value.dport
      proto   = "tcp"
      comment = "Talos LB port from allowed network"
    }
  }

  # Allow VRRP advertisements from the peer LB instance (HA only).
  dynamic "rule" {
    for_each = var.ha_enabled ? [1] : []
    content {
      action  = "ACCEPT"
      type    = "in"
      proto   = "vrrp"
      source  = each.value.state == "MASTER" ? var.secondary_ip : var.lb_ip
      comment = "VRRP from peer load balancer"
    }
  }
}
