terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_config.api_url
  pm_api_token_id     = var.proxmox_config.token_id
  pm_api_token_secret = var.proxmox_config.token_secret
  pm_tls_insecure     = var.proxmox_config.insecure
}

# Воркер ноды
resource "proxmox_vm_qemu" "k8s_workers" {
  count = var.cluster_config.workers_count

  name        = "k8s-worker-${var.vmid_ranges.workers.start + count.index}"
  target_node = var.proxmox_config.node
  vmid        = var.vmid_ranges.workers.start + count.index
  description = "Воркер-нода #${count.index + 1} кластера ${var.cluster_config.cluster_name}"
  start_at_node_boot = true

  cpu {
    cores   = var.vm_specs.worker.cpu_cores
    sockets = var.vm_specs.worker.cpu_sockets
  }
  
  memory = var.vm_specs.worker.memory_mb

  clone      = "ubuntu-template"
  full_clone = true

  disk {
    slot    = "scsi0"
    size    = "${var.vm_specs.worker.disk_size_gb}G"
    storage = var.vm_specs.worker.disk_storage
    type    = "disk"
    format  = var.vm_specs.worker.disk_format
  }

  disk {
    slot    = "ide2"
    storage = var.vm_specs.worker.disk_storage
    type    = "cloudinit"
  }

  network {
    id      = 0
    model   = "virtio"
    bridge  = var.network_config.bridge
    # Уникальный MAC для каждого воркера
    macaddr = format("52:54:00:aa:bb:%02x", count.index)
  }

  # Автоматический статический IP для воркера
  worker_ip = cidrhost(var.network_config.subnet, var.static_ip_base + 10 + count.index)

  ciuser     = var.cloud_init.user
  sshkeys    = file(pathexpand(var.cloud_init.ssh_key_path))
  ipconfig0  = "ip=${local.worker_ip}/24,gw=${var.network_config.gateway}"
  nameserver = join(" ", var.network_config.dns_servers)
  
  agent = 1
  scsihw = "virtio-scsi-pci"
}

output "workers_info" {
  value = [
    for idx, vm in proxmox_vm_qemu.k8s_workers : {
      name    = vm.name
      vmid    = vm.vmid
      mac     = vm.network[0].macaddr
      ip      = cidrhost(var.network_config.subnet, var.static_ip_base + 10 + idx)
    }
  ]
}
