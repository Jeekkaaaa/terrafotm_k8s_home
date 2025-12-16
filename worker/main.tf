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
}

resource "proxmox_vm_qemu" "k8s_worker" {
  count = var.cluster_config.workers_count
  
  name        = "k8s-worker-${var.vmid_ranges.workers.start + count.index}"
  vmid        = var.vmid_ranges.workers.start + count.index
  target_node = var.target_node
  desc        = "K8s Worker ${count.index + 1}"
  clone       = "ubuntu-template"
  
  cpu {
    cores   = var.vm_specs.worker.cpu_cores
    sockets = var.vm_specs.worker.cpu_sockets
  }
  
  memory = var.vm_specs.worker.memory_mb
  
  disk {
    slot     = 0
    type     = "scsi"
    storage  = var.vm_specs.worker.disk_storage
    size     = "${var.vm_specs.worker.disk_size_gb}G"
    iothread = var.vm_specs.worker.disk_iothread
  }
  
  disk {
    slot    = 2
    type    = "cloudinit"
    storage = var.vm_specs.worker.cloudinit_storage
  }
  
  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_config.bridge
  }
  
  # Динамический IP: мастер занимает первый IP, воркеры следующие
  ipconfig0 = "ip=${local.subnet_prefix}.${var.static_ip_base + count.index + var.cluster_config.masters_count}/24,gw=${var.network_config.gateway}"
  
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
