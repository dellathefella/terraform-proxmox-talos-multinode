module "lb" {
  source = "./modules/lb"

  cluster_name                = var.cluster_name
  lb_ip                       = local.cluster_lb_lxc_ip
  lan_subnet_cidr_bitnum      = local.lan_subnet_cidr_bitnum
  network_gateway             = var.network_gateway
  settings                    = var.cluster_lb_lxc_settings
  control_plane_ips           = [for node in local.listed_control_plane_nodes : node.ip]
  worker_ips                  = [for node in local.listed_worker_nodes : node.ip]
  allowed_networks            = var.allowed_networks
  http_proxy                  = var.http_proxy
  authorized_keys_file        = var.authorized_keys_file
  authorized_private_key_file = var.authorized_private_key_file
  ha_enabled                  = var.lb_ha_enabled
  vip                         = var.lb_vip
  secondary_ip                = local.cluster_lb_secondary_ip
  vrrp_router_id              = var.lb_vrrp_router_id
  secondary_node_name         = var.lb_secondary_node_name
  firewall_enabled            = var.lb_firewall_enabled
}

module "control_plane" {
  source = "./modules/control_plane"

  depends_on = [module.lb]

  cluster_name           = var.cluster_name
  nodes                  = local.listed_control_plane_nodes
  network_gateway        = var.network_gateway
  lan_subnet_cidr_bitnum = local.lan_subnet_cidr_bitnum
  talos_image_ids        = { for k, v in proxmox_download_file.talos_image : k => v.id }
}

module "workers" {
  source = "./modules/workers"

  depends_on = [module.control_plane]

  cluster_name           = var.cluster_name
  nodes                  = local.listed_worker_nodes
  network_gateway        = var.network_gateway
  lan_subnet_cidr_bitnum = local.lan_subnet_cidr_bitnum
  talos_image_ids        = { for k, v in proxmox_download_file.talos_image : k => v.id }
}

module "talos" {
  source = "./modules/talos"

  depends_on = [module.lb, module.control_plane, module.workers]

  cluster_name         = var.cluster_name
  control_plane_nodes  = local.listed_control_plane_nodes
  worker_nodes         = local.listed_worker_nodes
  lb_ip                = local.cluster_endpoint_ip
  api_hostnames        = var.api_hostnames
  control_plane_vm_ids = module.control_plane.vm_ids
  worker_vm_ids        = module.workers.vm_ids
}

resource "proxmox_virtual_environment_pool" "cluster_pool" {
  count = var.create_pve_pool ? 1 : 0

  pool_id = var.cluster_name
  comment = "Talos cluster ${var.cluster_name} - managed by terraform-proxmox-talos-multinode"
}

locals {
  # Keyed by stable names (known at plan time); the vm_id values are unknown
  # until apply, which is fine for for_each as long as the keys are static.
  cluster_guests = merge(
    { for k, v in module.lb.lb_container_ids : "lb-${k}" => v },
    { for k, v in module.control_plane.vm_ids : "cp-${k}" => v },
    { for k, v in module.workers.vm_ids : "wk-${k}" => v }
  )
}

resource "proxmox_pool_membership" "cluster_members" {
  for_each = var.create_pve_pool ? local.cluster_guests : {}

  pool_id = proxmox_virtual_environment_pool.cluster_pool[0].pool_id
  vm_id   = each.value
}

resource "proxmox_backup_job" "cluster_backup" {
  count = var.pbs_datastore_id != null && var.create_pve_pool ? 1 : 0

  id       = "${var.cluster_name}-nightly"
  schedule = var.backup_schedule
  storage  = var.pbs_datastore_id
  pool     = proxmox_virtual_environment_pool.cluster_pool[0].pool_id
  mode     = "snapshot"

  prune_backups = {
    keep-last    = "7"
    keep-weekly  = "4"
    keep-monthly = "6"
  }
}
