locals {
  factory_url = "https://factory.talos.dev"
  platform    = "nocloud"
  arch        = "amd64"
  version     = var.cluster_talos_version

  schematic    = file("${path.module}/talos/schematic.yaml")
  schematic_id = jsondecode(data.http.schematic_id.response_body)["id"]
  image_id     = "${local.schematic_id}_${local.version}"

  proxmox_node_names = toset(concat(
    [for mapped_worker_node in local.mapped_worker_nodes : mapped_worker_node.node_name],
    [for mapped_master_node in local.mapped_control_plane_nodes : mapped_master_node.node_name]
  ))
}

data "http" "schematic_id" {
  url          = "${local.factory_url}/schematics"
  method       = "POST"
  request_body = local.schematic
}

resource "proxmox_virtual_environment_download_file" "talos_image" {
  for_each     = local.proxmox_node_names
  node_name    = each.key
  content_type = "iso"
  datastore_id = "local"

  file_name               = "${var.cluster_name}-talos-${local.image_id}-${local.platform}-${local.arch}.img"
  url                     = "${local.factory_url}/image/${split("_", local.image_id)[0]}/${split("_", local.image_id)[1]}/${local.platform}-${local.arch}.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}