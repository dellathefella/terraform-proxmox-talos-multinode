# workers

Talos worker node VMs on Proxmox, with optional additional storage disks.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.113.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | ~> 0.113.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_virtual_environment_vm.vm](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster. | `string` | n/a | yes |
| <a name="input_lan_subnet_cidr_bitnum"></a> [lan\_subnet\_cidr\_bitnum](#input\_lan\_subnet\_cidr\_bitnum) | CIDR bit number of the LAN subnet (e.g. '24'). | `string` | n/a | yes |
| <a name="input_network_gateway"></a> [network\_gateway](#input\_network\_gateway) | IP address of the network gateway. | `string` | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Worker nodes with pre-computed names and IPs. | <pre>list(object({<br/>    name           = string,<br/>    node_name      = string,<br/>    i              = number,<br/>    ip             = string,<br/>    taints         = list(string),<br/>    cores          = number,<br/>    memory         = number,<br/>    datastore_id   = string,<br/>    install_disks  = list(string),<br/>    disk_size      = number,<br/>    network_bridge = string,<br/>    additional_storage = optional(object({<br/>      datastore_id = string,<br/>      disk_size    = number,<br/>    }), null)<br/>  }))</pre> | n/a | yes |
| <a name="input_talos_image_ids"></a> [talos\_image\_ids](#input\_talos\_image\_ids) | Map of Proxmox node name to Talos image file ID. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_vm_ids"></a> [vm\_ids](#output\_vm\_ids) | Worker Proxmox VM IDs, keyed by '<pool-name>-<index>'. |
<!-- END_TF_DOCS -->
