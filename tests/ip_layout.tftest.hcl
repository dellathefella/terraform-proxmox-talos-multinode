run "ip_layout_standard" {
  command = plan

  variables {
    cluster_name                = "test"
    authorized_keys_file        = "README.md"
    authorized_private_key_file = "README.md"
    network_gateway             = "10.0.0.1"
    lan_subnet                  = "10.0.0.0/24"
    control_plane_subnet        = "10.0.6.0/29"
    control_plane_nodes = [
      { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" },
      { node_name = "pve1", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" },
      { node_name = "pve2", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" }
    ]
    node_pools = [
      {
        subnet    = "10.0.6.8/29"
        node_name = "pve0"
        size      = 2
        node_pool_settings = {
          name           = "pool0"
          cores          = 8
          memory         = 10240
          datastore_id   = "local-lvm"
          disk_size      = 120
          network_bridge = "vmbr0"
        }
      }
    ]
  }

  assert {
    condition     = local.cluster_lb_lxc_ip == "10.0.6.1"
    error_message = "LB LXC must take .1 of control_plane_subnet, got ${local.cluster_lb_lxc_ip}"
  }

  assert {
    condition     = [for n in local.listed_control_plane_nodes : n.ip] == ["10.0.6.2", "10.0.6.3", "10.0.6.4"]
    error_message = "Control plane nodes must take .2-.4, got ${jsonencode([for n in local.listed_control_plane_nodes : n.ip])}"
  }

  assert {
    condition     = [for n in local.listed_worker_nodes : n.ip] == ["10.0.6.9", "10.0.6.10"]
    error_message = "Workers must start at .1 of the pool subnet (never the network address), got ${jsonencode([for n in local.listed_worker_nodes : n.ip])}"
  }

  assert {
    condition     = local.cluster_endpoint_ip == "10.0.6.1"
    error_message = "Without HA the endpoint must be the primary LB IP"
  }
}

run "ip_layout_ha" {
  command = plan

  variables {
    cluster_name                = "test"
    authorized_keys_file        = "README.md"
    authorized_private_key_file = "README.md"
    network_gateway             = "10.0.0.1"
    lan_subnet                  = "10.0.0.0/24"
    control_plane_subnet        = "10.0.6.0/29"
    lb_ha_enabled               = true
    lb_vip                      = "10.0.6.7"
    lb_secondary_node_name      = "pve1"
    control_plane_nodes = [
      { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" },
      { node_name = "pve2", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" },
      { node_name = "pve3", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" }
    ]
    node_pools = []
  }

  assert {
    condition     = local.cluster_lb_secondary_ip == "10.0.6.2"
    error_message = "Secondary LB must take .2 when HA is enabled"
  }

  assert {
    condition     = [for n in local.listed_control_plane_nodes : n.ip] == ["10.0.6.3", "10.0.6.4", "10.0.6.5"]
    error_message = "With HA, control plane nodes must shift to .3+, got ${jsonencode([for n in local.listed_control_plane_nodes : n.ip])}"
  }

  assert {
    condition     = local.cluster_endpoint_ip == "10.0.6.7"
    error_message = "With HA the endpoint must be the VIP"
  }
}

run "empty_control_plane_rejected" {
  command = plan

  variables {
    cluster_name                = "test"
    authorized_keys_file        = "README.md"
    authorized_private_key_file = "README.md"
    network_gateway             = "10.0.0.1"
    lan_subnet                  = "10.0.0.0/24"
    control_plane_subnet        = "10.0.6.0/29"
    control_plane_nodes         = []
    node_pools                  = []
  }

  expect_failures = [var.control_plane_nodes]
}

run "even_control_plane_count_rejected" {
  command = plan

  variables {
    cluster_name                = "test"
    authorized_keys_file        = "README.md"
    authorized_private_key_file = "README.md"
    network_gateway             = "10.0.0.1"
    lan_subnet                  = "10.0.0.0/24"
    control_plane_subnet        = "10.0.6.0/29"
    control_plane_nodes = [
      { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" },
      { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" }
    ]
    node_pools = []
  }

  expect_failures = [var.control_plane_nodes]
}

run "duplicate_pool_names_rejected" {
  command = plan

  variables {
    cluster_name                = "test"
    authorized_keys_file        = "README.md"
    authorized_private_key_file = "README.md"
    network_gateway             = "10.0.0.1"
    lan_subnet                  = "10.0.0.0/24"
    control_plane_subnet        = "10.0.6.0/29"
    control_plane_nodes = [
      { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" }
    ]
    node_pools = [
      {
        subnet             = "10.0.6.8/29"
        node_name          = "pve0"
        size               = 1
        node_pool_settings = { name = "same", cores = 2, memory = 2048, datastore_id = "local-lvm", disk_size = 20, network_bridge = "vmbr0" }
      },
      {
        subnet             = "10.0.6.16/29"
        node_name          = "pve0"
        size               = 1
        node_pool_settings = { name = "same", cores = 2, memory = 2048, datastore_id = "local-lvm", disk_size = 20, network_bridge = "vmbr0" }
      }
    ]
  }

  expect_failures = [var.node_pools]
}

run "pool_subnet_too_small_rejected" {
  command = plan

  variables {
    cluster_name                = "test"
    authorized_keys_file        = "README.md"
    authorized_private_key_file = "README.md"
    network_gateway             = "10.0.0.1"
    lan_subnet                  = "10.0.0.0/24"
    control_plane_subnet        = "10.0.6.0/29"
    control_plane_nodes = [
      { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" }
    ]
    node_pools = [
      {
        subnet             = "10.0.6.8/29"
        node_name          = "pve0"
        size               = 7
        node_pool_settings = { name = "big", cores = 2, memory = 2048, datastore_id = "local-lvm", disk_size = 20, network_bridge = "vmbr0" }
      }
    ]
  }

  expect_failures = [var.node_pools]
}

run "ha_without_vip_rejected" {
  command = plan

  variables {
    cluster_name                = "test"
    authorized_keys_file        = "README.md"
    authorized_private_key_file = "README.md"
    network_gateway             = "10.0.0.1"
    lan_subnet                  = "10.0.0.0/24"
    control_plane_subnet        = "10.0.6.0/29"
    lb_ha_enabled               = true
    control_plane_nodes = [
      { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" }
    ]
    node_pools = []
  }

  expect_failures = [check.lb_ha_vip_required, check.lb_ha_secondary_node_separation]
}

run "ha_without_node_separation_rejected" {
  command = plan

  variables {
    cluster_name                = "test"
    authorized_keys_file        = "README.md"
    authorized_private_key_file = "README.md"
    network_gateway             = "10.0.0.1"
    lan_subnet                  = "10.0.0.0/24"
    control_plane_subnet        = "10.0.6.0/29"
    lb_ha_enabled               = true
    lb_vip                      = "10.0.6.7"
    control_plane_nodes = [
      { node_name = "pve0", cores = 4, memory = 4096, datastore_id = "local-lvm", disk_size = 16, network_bridge = "vmbr0" }
    ]
    node_pools = []
  }

  expect_failures = [check.lb_ha_secondary_node_separation]
}
