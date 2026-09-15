resource "talos_machine_secrets" "cluster_machine_secret" {}

# terraform_data shims: propagate VM replacement into this module, since
# replace_triggered_by cannot reference input variables directly.
resource "terraform_data" "control_plane_replacement" {
  for_each = var.control_plane_vm_ids
  input    = each.value
}

resource "terraform_data" "worker_replacement" {
  for_each = var.worker_vm_ids
  input    = each.value
}

data "talos_client_configuration" "cluster_client_configuration" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  endpoints            = concat([for node in var.control_plane_nodes : node.ip], [var.lb_ip])
  nodes                = [for node in var.worker_nodes : node.ip]
}

# Write talosconfig to disk so it can be consumed without exposing it as a
# sensitive output. (The ephemeral variant of this data source offers a crt_ttl
# knob but cannot be written to local_file, which is not a write-only target.)
resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.cluster_client_configuration.talos_config
  filename        = "${path.root}/talosconfig"
  file_permission = "0600"
}

### Control plane nodes ###
data "talos_machine_configuration" "control_plane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.lb_ip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster_machine_secret.machine_secrets
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each                    = { for node in var.control_plane_nodes : node.name => node }
  client_configuration        = talos_machine_secrets.cluster_machine_secret.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                        = each.value.ip
  config_patches = concat(
    [
      templatefile("${path.root}/config/control-plane.yaml.tmpl", {
        hostname      = each.value.name
        cluster_name  = var.cluster_name
        install_disks = each.value.install_disks
        api_hostnames = var.api_hostnames
      }),
    ],
    each.value.extra_config_patches
  )
  lifecycle {
    replace_triggered_by = [
      terraform_data.control_plane_replacement[each.key]
    ]
  }
}

resource "talos_machine_bootstrap" "control_plane" {
  depends_on = [
    talos_machine_configuration_apply.control_plane
  ]
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  node                 = [for node in var.control_plane_nodes : node.ip][0]
}

data "talos_cluster_health" "control_plane" {
  depends_on = [
    talos_machine_bootstrap.control_plane
  ]
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  control_plane_nodes  = [for node in var.control_plane_nodes : node.ip]
  endpoints            = [var.lb_ip]

  timeouts = {
    read = "30m"
  }
}
### Control plane nodes ###

## Worker nodes ###
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.lb_ip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster_machine_secret.machine_secrets
}

resource "talos_machine_configuration_apply" "worker" {
  depends_on = [
    talos_machine_bootstrap.control_plane,
    data.talos_cluster_health.control_plane
  ]
  for_each                    = { for node in var.worker_nodes : "${node.name}-${node.i}" => node }
  client_configuration        = talos_machine_secrets.cluster_machine_secret.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.ip
  config_patches = concat(
    [
      templatefile("${path.root}/config/worker.yaml.tmpl", {
        hostname      = "${var.cluster_name}-${each.key}"
        node_taints   = each.value.taints
        install_disks = each.value.install_disks
      }),
    ],
    each.value.additional_storage != null ? [
      file("${path.root}/config/worker-storage.yaml")
    ] : [],
    each.value.extra_config_patches
  )
  lifecycle {
    replace_triggered_by = [
      terraform_data.worker_replacement[each.key]
    ]
  }
}

data "talos_cluster_health" "workers" {
  count = length(var.worker_nodes) > 0 ? 1 : 0

  depends_on = [
    talos_machine_configuration_apply.worker
  ]
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  control_plane_nodes  = [for node in var.control_plane_nodes : node.ip]
  worker_nodes         = [for node in var.worker_nodes : node.ip]
  endpoints            = [var.lb_ip]

  timeouts = {
    read = "30m"
  }
}
## Worker nodes ###

resource "talos_cluster_kubeconfig" "cluster_kubeconfig" {
  depends_on = [
    talos_machine_bootstrap.control_plane
  ]
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  node                 = [for node in var.control_plane_nodes : node.ip][0]
}
