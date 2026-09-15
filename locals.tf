locals {
  lan_subnet_cidr_bitnum = split("/", var.lan_subnet)[1]

  # Index 1: the network address (index 0) is not assignable.
  cluster_lb_lxc_ip = cidrhost(var.control_plane_subnet, 1)

  # With HA, the secondary LB LXC takes .2 and control plane nodes shift to .3+.
  cluster_lb_secondary_ip = var.lb_ha_enabled ? cidrhost(var.control_plane_subnet, 2) : null
  control_plane_ip_offset = var.lb_ha_enabled ? 3 : 2

  # What the cluster API endpoint resolves to (VIP when HA, primary LB otherwise).
  cluster_endpoint_ip = var.lb_ha_enabled ? var.lb_vip : local.cluster_lb_lxc_ip

  listed_control_plane_nodes = flatten([
    for i, master_node in var.control_plane_nodes : merge(master_node, {
      name = "${var.cluster_name}-control-plane-${i}"
      i    = i
      ip   = cidrhost(var.control_plane_subnet, i + local.control_plane_ip_offset)
    })
  ])

  mapped_control_plane_nodes = {
    for node in local.listed_control_plane_nodes : node.name => node
  }

  listed_worker_nodes = flatten([
    for pool in var.node_pools :
    [
      for i in range(pool.size) :
      merge(pool.node_pool_settings, {
        node_name = pool.node_name
        i         = i
        ip        = cidrhost(pool.subnet, i + 1)
      })
    ]
  ])

  mapped_worker_nodes = {
    for node in local.listed_worker_nodes : "${node.name}-${node.i}" => node
  }

  proxmox_node_names = toset(concat(
    [for mapped_worker_node in local.mapped_worker_nodes : mapped_worker_node.node_name],
    [for mapped_master_node in local.mapped_control_plane_nodes : mapped_master_node.node_name]
  ))
}
