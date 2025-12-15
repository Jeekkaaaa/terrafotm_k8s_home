terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

locals {
  master_indices = range(var.cluster_config.masters_count)
}

resource "proxmox_vm_qemu" "k8s_master" {
  for_each = { for idx in local.master_indices : idx => idx }

  name        = "k8s-master-${var.vmid_ranges.masters.start + each.key}"
  target_node = var.target_node
  vmid        = var.vmid_ranges.masters.start + each.key
  description = "K8s Master ${each.key + 1}"
  
  clone = "ubuntu-template"
  full_clone = true
  
  cpu {
    cores   = var.vm_specs.master.cpu_cores
    sockets = var.vm_specs.master.cpu_sockets
  }
  
  memory  = var.vm_specs.master.memory_mb
  start_at_node_boot = true
  
  disk {
    slot     = 0
    type     = "scsi"
    storage  = var.vm_specs.master.disk_storage
    size     = "${var.vm_specs.master.disk_size_gb}G"
    iothread = var.vm_specs.master.disk_iothread
  }
  
  disk {
    slot    = 2
    type    = "cloudinit"
    storage = var.vm_specs.master.cloudinit_storage
  }
  
  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_config.bridge
  }
  
  ciuser       = var.cloud_init.user
  sshkeys      = file(var.ssh_public_key_path)
  ipconfig0    = var.auto_static_ips ? "ip=${cidrhost(var.network_config.subnet, var.static_ip_base + each.key)}/24,gw=${var.network_config.gateway}" : "ip=dhcp"
  nameserver   = join(" ", var.network_config.dns_servers)
  searchdomain = join(" ", var.cloud_init.search_domains)
  
  agent  = 1
  scsihw = "virtio-scsi-single"
}

output "masters" {
  value = {
    for idx, vm in proxmox_vm_qemu.k8s_master : idx => {
      name = vm.name
      vmid = vm.vmid
      ip   = var.auto_static_ips ? cidrhost(var.network_config.subnet, var.static_ip_base + idx) : "dhcp"
    }
  }
}
