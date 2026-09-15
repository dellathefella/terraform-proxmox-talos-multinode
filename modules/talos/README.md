# talos

Talos cluster lifecycle: secrets, machine configuration, config apply, bootstrap,
health gates, and kubeconfig/talosconfig.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.2.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | ~> 0.11.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_local"></a> [local](#provider\_local) | ~> 2.2.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | ~> 0.11.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [local_file.talosconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [talos_cluster_kubeconfig.cluster_kubeconfig](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.control_plane](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.control_plane](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_configuration_apply.worker](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.cluster_machine_secret](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [terraform_data.control_plane_replacement](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.worker_replacement](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [talos_client_configuration.cluster_client_configuration](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_cluster_health.control_plane](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/cluster_health) | data source |
| [talos_cluster_health.workers](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/cluster_health) | data source |
| [talos_machine_configuration.control_plane](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |
| [talos_machine_configuration.worker](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_api_hostnames"></a> [api\_hostnames](#input\_api\_hostnames) | Alternative hostnames for the API server. | `list(string)` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster. | `string` | n/a | yes |
| <a name="input_control_plane_nodes"></a> [control\_plane\_nodes](#input\_control\_plane\_nodes) | Control plane nodes with pre-computed names and IPs. | <pre>list(object({<br/>    name                 = string,<br/>    ip                   = string,<br/>    install_disks        = list(string),<br/>    extra_config_patches = optional(list(string), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_control_plane_vm_ids"></a> [control\_plane\_vm\_ids](#input\_control\_plane\_vm\_ids) | Map of control plane node name to Proxmox VM ID (drives replacement of machine config applies). | `map(string)` | n/a | yes |
| <a name="input_lb_ip"></a> [lb\_ip](#input\_lb\_ip) | IP address of the cluster load balancer (API endpoint). | `string` | n/a | yes |
| <a name="input_worker_nodes"></a> [worker\_nodes](#input\_worker\_nodes) | Worker nodes with pre-computed names and IPs. | <pre>list(object({<br/>    name          = string,<br/>    i             = number,<br/>    ip            = string,<br/>    taints        = list(string),<br/>    install_disks = list(string),<br/>    additional_storage = optional(object({<br/>      datastore_id = string,<br/>      disk_size    = number,<br/>    }), null)<br/>    extra_config_patches = optional(list(string), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_worker_vm_ids"></a> [worker\_vm\_ids](#input\_worker\_vm\_ids) | Map of '<pool-name>-<index>' to Proxmox VM ID (drives replacement of machine config applies). | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_kube_config"></a> [kube\_config](#output\_kube\_config) | Kubernetes configuration file. |
| <a name="output_talosconfig_path"></a> [talosconfig\_path](#output\_talosconfig\_path) | Path to the talosconfig file written at plan time (kept out of Terraform state). |
| <a name="output_worker_health_check_passed"></a> [worker\_health\_check\_passed](#output\_worker\_health\_check\_passed) | True once the post-join worker health check has passed. |
<!-- END_TF_DOCS -->
