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

# Локальные вычисления
locals {
  subnet_prefix = split(".", var.network_config.subnet)[0]
  master_ip     = "${local.subnet_prefix}.${var.static_ip_base}"
}

resource "proxmox_virtual_environment_vm" "k8s_master" {
  name      = "k8s-master-${var.vmid_ranges.masters.start}"
  node_name = var.target_node
  vm_id     = var.vmid_ranges.masters.start
  
  # КЛОНИРУЕМ ИЗ ШАБЛОНА
  clone {
    vm_id = var.template_vmid  # ID вашего шаблона (9001)
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

  # НАСТРОЙКА ДИСКА (после клонирования)
  disk {
    datastore_id = var.vm_specs.master.disk_storage
    size         = var.vm_specs.master.disk_size_gb
    iothread     = var.vm_specs.master.disk_iothread
    interface    = "scsi0"
  }

  # CLOUD-INIT КОНФИГУРАЦИЯ
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
        address = "${local.master_ip}/24"
        gateway = var.network_config.gateway
      }
    }
  }

  network_device {
    bridge = var.network_config.bridge
    model  = "virtio"
  }

  agent {
    enabled = true
    type    = "virtio"
  }

  boot_order = ["scsi0"]
  scsi_hardware = "virtio-scsi-pci"
  on_boot = true

  lifecycle {
    ignore_changes = [
      disk[0].size,
      network_device,
    ]
  }
}

output "master_ip" {
  value = local.master_ip
}

output "master_ready" {
  value = "Master node ${var.vmid_ranges.masters.start} создан с IP ${local.master_ip}"
}
