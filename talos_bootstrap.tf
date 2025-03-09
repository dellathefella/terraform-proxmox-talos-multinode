resource "talos_machine_secrets" "cluster_machine_secret" {}


data "talos_client_configuration" "cluster_client_configuration" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  endpoints            = concat([for k, v in local.listed_master_nodes : v.ip], [local.support_node_ip])
  nodes                = [for k, v in local.listed_worker_nodes : v.ip]
}

### Control plane nodes ###
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.support_node_ip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster_machine_secret.machine_secrets
}


resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [
    data.talos_machine_configuration.controlplane
  ]
  for_each = { for node in local.listed_master_nodes : "${node.name}" => node }
  client_configuration        = talos_machine_secrets.cluster_machine_secret.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.ip
  config_patches = [
    templatefile("${path.module}/config/control-plane.yaml.tmpl", {
      hostname = "${each.value.name}"
      install_disk   = each.value.install_disk
      longhorn_install = file("${path.module}/kubernetes/longhorn-v1.7.0.yaml")

      #   cilium_install = file("${path.module}/kubernetes/cilium-install.yaml")
      #   zfs_setup      = file("${path.module}/kubernetes/zfs-setup.yaml")
    }),
    #file("${path.module}/config/falco-patch.yaml"),
  ]
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_vm.talos-master
    ]
  }
}

resource "talos_machine_bootstrap" "controlplane" {
  depends_on = [talos_machine_configuration_apply.controlplane]
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  node                 =  [for k, v in local.listed_master_nodes : v.ip][0]
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_vm.talos-master
    ]
  }
}
### Control plane nodes ###

## Worker nodes ###
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.support_node_ip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster_machine_secret.machine_secrets
}


resource "talos_machine_configuration_apply" "worker" {
  depends_on = [
    talos_machine_bootstrap.controlplane
  ]
  for_each = { for node in local.listed_worker_nodes : "${node.name}-${node.i}" => node }
  client_configuration        = talos_machine_secrets.cluster_machine_secret.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.ip
  config_patches = [
    templatefile("${path.module}/config/worker.yaml.tmpl", {
      hostname = "${var.cluster_name}-${each.key}",
      install_disk = each.value.install_disk
      #   cilium_install = file("${path.module}/kubernetes/cilium-install.yaml")
      #   zfs_setup      = file("${path.module}/kubernetes/zfs-setup.yaml")
    }),
    #file("${path.module}/config/falco-patch.yaml"),
  ]
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_vm.talos-worker
    ]
  }
}
## Worker nodes ###


resource "talos_cluster_kubeconfig" "cluster_kubeconfig" {
  depends_on           = [talos_machine_bootstrap.controlplane]
  client_configuration = talos_machine_secrets.cluster_machine_secret.client_configuration
  node                 =  [for k, v in local.listed_master_nodes : v.ip][0]
}