locals {
  platform = "nocloud"
  arch     = var.talos_arch
}

resource "talos_image_factory_schematic" "this" {
  schematic = file("${path.module}/talos/schematics.yaml")
}

data "talos_image_factory_urls" "talos_image" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = local.platform
  architecture  = local.arch
}

resource "proxmox_download_file" "talos_image" {
  for_each     = local.proxmox_node_names
  node_name    = each.key
  content_type = "iso"
  datastore_id = "local"

  file_name               = "${var.cluster_name}-talos-${talos_image_factory_schematic.this.id}-${local.platform}-${local.arch}.img"
  url                     = data.talos_image_factory_urls.talos_image.urls.disk_image
  decompression_algorithm = "gz"
  overwrite               = false
}
