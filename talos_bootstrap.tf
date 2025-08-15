resource "talos_machine_secrets" "cluster_machine_secret" {
  talos_version = local.version
}


data "talos_client_configuration" "cluster_client_configuration" {
  depends_on = [
    null_resource.talos_nginx_install
  ]
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  endpoints            = concat([for k, v in local.listed_control_plane_nodes : v.ip], [local.cluster_lb_vm_ip])
  nodes                = [for k, v in local.listed_worker_nodes : v.ip]
}

### Control plane nodes ###
data "talos_machine_configuration" "control_plane" {
  depends_on = [
    null_resource.talos_nginx_install
  ]
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.cluster_lb_vm_ip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster_machine_secret.machine_secrets
}


resource "talos_machine_configuration_apply" "control_plane" {
  depends_on = [
    data.talos_machine_configuration.control_plane,
    null_resource.talos_nginx_install
  ]
  for_each                    = { for node in local.listed_control_plane_nodes : "${node.name}" => node }
  client_configuration        = talos_machine_secrets.cluster_machine_secret.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                        = each.value.ip
  config_patches = [
    templatefile("${path.module}/config/control-plane.tmpl.yaml", {
      allows_scheduling_on_control_plane_nodes = var.allows_scheduling_on_control_plane_nodes
      hostname                                 = "${each.value.name}"
      bgp                                      = var.bgp
      cluster_name                             = var.cluster_name
      install_disk                             = each.value.install_disk
      longhorn_install                         = file("${path.module}/kubernetes/longhorn-v1.9.0.yaml")
      flux_install                             = file("${path.module}/kubernetes/flux-v2.6.4.yaml")
      cilium_install                           = file("${path.module}/kubernetes/cilium-install.yaml")
      cilium_values                            = file("${path.module}/kubernetes/cilium-values.yaml")
    }),
    #file("${path.module}/config/falco-patch.yaml"),
  ]
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_vm.talos_control_plane
    ]
  }
}

resource "talos_machine_bootstrap" "control_plane" {
  depends_on = [
    talos_machine_configuration_apply.control_plane,
    null_resource.talos_nginx_install
  ]
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  node                 = [for v in local.listed_control_plane_nodes : v.ip][0]
}
### Control plane nodes ###

## Worker nodes ###
data "talos_machine_configuration" "worker" {
  depends_on = [
    null_resource.talos_nginx_install
  ]
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.cluster_lb_vm_ip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster_machine_secret.machine_secrets
}


resource "talos_machine_configuration_apply" "worker" {
  depends_on = [
    talos_machine_bootstrap.control_plane,
    null_resource.talos_nginx_install
  ]
  for_each                    = { for node in local.listed_worker_nodes : "${node.name}-${node.i}" => node }
  client_configuration        = talos_machine_secrets.cluster_machine_secret.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.ip
  config_patches = [
    templatefile("${path.module}/config/worker.tmpl.yaml", {
      hostname     = "${var.cluster_name}-${each.key}",
      bgp          = var.bgp
      node_taints  = each.value.taints
      install_disk = each.value.install_disk
      nodepool     = each.value.nodepool_name
    }),
    #file("${path.module}/config/falco-patch.yaml"),
  ]
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_vm.talos_worker
    ]
  }
}
## Worker nodes ###


resource "talos_cluster_kubeconfig" "cluster_kubeconfig" {
  depends_on = [
    talos_machine_bootstrap.control_plane,
    null_resource.talos_nginx_install
  ]
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  node                 = [for v in local.listed_control_plane_nodes : v.ip][0]
}