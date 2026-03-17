terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.56.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
  insecure  = true
  
  ssh {
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
  }
}

locals {
  subnet_parts = split(".", var.network_config.subnet)
  network_prefix = "${local.subnet_parts[0]}.${local.subnet_parts[1]}.${local.subnet_parts[2]}"
  
  # Создаем список IP для master нод
  master_ips = [
    for i in range(var.cluster_config.masters_count) : 
    "${local.network_prefix}.${var.static_ip_base + i}"
  ]
}

# ДОБАВЛЕНО: Используем count вместо одного ресурса
resource "proxmox_virtual_environment_vm" "k8s_master" {
  count = var.cluster_config.masters_count  # <-- КЛЮЧЕВОЕ ИЗМЕНЕНИЕ

  name      = "k8s-master-${var.vmid_ranges.masters.start + count.index}"  # <-- Используем count.index
  node_name = var.target_node
  vm_id     = var.vmid_ranges.masters.start + count.index  # <-- Используем count.index
  started   = true

  clone {
    vm_id = var.template_vmid
    node_name = var.target_node
    full = true
  }

  cpu {
    cores   = var.vm_specs.master.cpu_cores
    sockets = var.vm_specs.master.cpu_sockets
  }

  memory {
    dedicated = var.vm_specs.master.memory_mb
  }

  # ВАЖНО: file_format = "raw" для LVM
  disk {
    datastore_id = var.vm_specs.master.disk_storage
    size         = var.vm_specs.master.disk_size_gb
    interface    = "scsi0"
    file_format  = "raw"  # RAW для LVM хранилища!
  }

  initialization {
    datastore_id = var.vm_specs.master.cloudinit_storage

    user_account {
      username = var.cloud_init.user
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = var.network_config.dns_servers
      domain  = var.cloud_init.search_domains[0]
    }

    ip_config {
      ipv4 {
        address = "${local.master_ips[count.index]}/24"  # <-- Используем массив IP
        gateway = var.network_config.gateway
      }
    }
  }

  network_device {
    bridge = var.network_config.bridge
    model  = "virtio"
  }

  agent {
    enabled = false
  }

  boot_order = ["scsi0"]
  scsi_hardware = "virtio-scsi-pci"
  on_boot = true

  timeout_create = 300

  lifecycle {
    ignore_changes = [
      disk[0].size,
      network_device,
    ]
  }
}

output "master_ips" {
  value = local.master_ips
}
