terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">=0.7.1"
    }
  }
}