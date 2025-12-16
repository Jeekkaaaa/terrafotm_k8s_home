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

# Локальные вычисления
locals {
  subnet_prefix = split(".", var.network_config.subnet)[0]
  master_ip     = "${local.subnet_prefix}.${var.static_ip_base}"
}

resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-${var.vmid_ranges.masters.start}"
  vmid        = var.vmid_ranges.masters.start
  target_node = var.target_node
  desc        = "K8s Master Node"
  clone       = "ubuntu-template"
  
  cpu {
    cores   = var.vm_specs.master.cpu_cores
    sockets = var.vm_specs.master.cpu_sockets
  }
  
  memory = var.vm_specs.master.memory_mb
  
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
  
  ipconfig0 = "ip=${local.master_ip}/24,gw=${var.network_config.gateway}"
  
  ciuser       = var.cloud_init.user
  searchdomain = join(" ", var.cloud_init.search_domains)
  nameserver   = join(" ", var.network_config.dns_servers)
  sshkeys      = var.ssh_public_key
  
  boot      = "order=scsi0"
  bootdisk  = "scsi0"
  scsihw    = "virtio-scsi-pci"
  agent     = 1
  os_type   = "cloud-init"
  
  lifecycle {
    ignore_changes = [
      disk[0].size,
      network,
    ]
  }
}
