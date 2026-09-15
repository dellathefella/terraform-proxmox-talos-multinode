# lb

Cluster load balancer LXC(s): nginx stream LB for the Talos API, ingress, and
extra ports; optional keepalived HA pair; optional Proxmox firewall.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.113.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.2.0 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | ~> 0.113.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [null_resource.keepalived_config](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.keepalived_install](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.talos_nginx_config](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.talos_nginx_install](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [proxmox_download_file.latest_ubuntu_24_noble_lxc_img](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/download_file) | resource |
| [proxmox_virtual_environment_container.cluster_lb](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container) | resource |
| [proxmox_virtual_environment_firewall_options.lb](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_firewall_options) | resource |
| [proxmox_virtual_environment_firewall_rules.lb](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_firewall_rules) | resource |
| [random_password.cluster_lb_lxc_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.vrrp_auth](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_networks"></a> [allowed\_networks](#input\_allowed\_networks) | CIDR ranges allowed to reach the load balancer ports. | `list(string)` | n/a | yes |
| <a name="input_authorized_keys_file"></a> [authorized\_keys\_file](#input\_authorized\_keys\_file) | Path to file containing public SSH keys. | `string` | n/a | yes |
| <a name="input_authorized_private_key_file"></a> [authorized\_private\_key\_file](#input\_authorized\_private\_key\_file) | Path to file containing the private SSH key. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster. | `string` | n/a | yes |
| <a name="input_control_plane_ips"></a> [control\_plane\_ips](#input\_control\_plane\_ips) | IP addresses of the control plane nodes. | `list(string)` | n/a | yes |
| <a name="input_firewall_enabled"></a> [firewall\_enabled](#input\_firewall\_enabled) | Enable the Proxmox firewall on the LB LXC(s) with default-deny inbound. | `bool` | `false` | no |
| <a name="input_ha_enabled"></a> [ha\_enabled](#input\_ha\_enabled) | Deploy the secondary LB instance with keepalived (VRRP). | `bool` | `false` | no |
| <a name="input_http_proxy"></a> [http\_proxy](#input\_http\_proxy) | HTTP(S) proxy URL used when installing packages. | `string` | n/a | yes |
| <a name="input_lan_subnet_cidr_bitnum"></a> [lan\_subnet\_cidr\_bitnum](#input\_lan\_subnet\_cidr\_bitnum) | CIDR bit number of the LAN subnet (e.g. '24'). | `string` | n/a | yes |
| <a name="input_lb_ip"></a> [lb\_ip](#input\_lb\_ip) | IP address assigned to the load balancer LXC. | `string` | n/a | yes |
| <a name="input_network_gateway"></a> [network\_gateway](#input\_network\_gateway) | IP address of the network gateway. | `string` | n/a | yes |
| <a name="input_secondary_ip"></a> [secondary\_ip](#input\_secondary\_ip) | IP address of the secondary LB LXC (required when ha\_enabled). | `string` | `null` | no |
| <a name="input_secondary_node_name"></a> [secondary\_node\_name](#input\_secondary\_node\_name) | Proxmox node for the secondary LB LXC. Defaults to the primary node. | `string` | `null` | no |
| <a name="input_settings"></a> [settings](#input\_settings) | Load balancer LXC settings. | <pre>object({<br/>    node_name                              = string,<br/>    cores                                  = number,<br/>    memory                                 = number,<br/>    datastore_id                           = string,<br/>    disk_size                              = number,<br/>    network_bridge                         = string,<br/>    additional_lb_worker_node_ports        = optional(list(number), [])<br/>    additional_lb_control_plane_node_ports = optional(list(number), [])<br/>    nginx_worker_connections               = optional(number, 768)<br/>  })</pre> | n/a | yes |
| <a name="input_vip"></a> [vip](#input\_vip) | Virtual (VRRP) IP address for the HA load balancer endpoint. | `string` | `""` | no |
| <a name="input_vrrp_router_id"></a> [vrrp\_router\_id](#input\_vrrp\_router\_id) | VRRP virtual router ID. | `number` | `51` | no |
| <a name="input_worker_ips"></a> [worker\_ips](#input\_worker\_ips) | IP addresses of the worker nodes. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_lb_container_ids"></a> [lb\_container\_ids](#output\_lb\_container\_ids) | Proxmox CT IDs of the load balancer LXC(s), keyed by instance role. |
| <a name="output_lb_ip"></a> [lb\_ip](#output\_lb\_ip) | IP address of the primary load balancer LXC. |
<!-- END_TF_DOCS -->
