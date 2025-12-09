terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_config.api_url
  pm_api_token_id     = var.proxmox_config.token_id
  pm_api_token_secret = var.proxmox_config.token_secret
  pm_tls_insecure     = var.proxmox_config.insecure
}

# Генерация уникальных значений
resource "random_integer" "vmid_offset" {
  min = 0
  max = var.vmid_ranges.masters.end - var.vmid_ranges.masters.start
  keepers = {
    timestamp = timestamp()
  }
}

resource "random_integer" "mac_part1" {
  min = 0
  max = 255
}

resource "random_integer" "mac_part2" {
  min = 0
  max = 255
}

resource "random_integer" "mac_part3" {
  min = 0
  max = 255
}

locals {
  # VMID
  master_vmid = var.vmid_ranges.masters.start + random_integer.vmid_offset.result
  
  # MAC
  mac_address = format("52:54:00:%02x:%02x:%02x",
    random_integer.mac_part1.result,
    random_integer.mac_part2.result,
    random_integer.mac_part3.result)
  
  # Автоматический статический IP
  master_ip = var.auto_static_ips ? 
    cidrhost(var.network_config.subnet, var.static_ip_base + (local.master_vmid - var.vmid_ranges.masters.start)) : 
    null
  
  # IP конфигурация
  ip_config = var.auto_static_ips ? 
    "ip=${local.master_ip}/24,gw=${var.network_config.gateway}" : 
    "ip=dhcp"
}

# Очистка старых мастеров
resource "null_resource" "cleanup" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Очистка старых мастер-нод..."
      for vmid in $(qm list | grep "k8s-master-" | awk '{print $1}'); do
        echo "Удаляем ВМ $vmid"
        qm stop $vmid 2>/dev/null || true
        qm destroy $vmid --purge 2>/dev/null || true
      done
      sleep 5
    EOT
  }
}

# Мастер-нода
resource "proxmox_vm_qemu" "k8s_master" {
  depends_on = [null_resource.cleanup]

  name        = "k8s-master-${local.master_vmid}"
  target_node = var.proxmox_config.node
  vmid        = local.master_vmid
  description = "Мастер-нода кластера ${var.cluster_config.cluster_name}"
  start_at_node_boot = true

  cpu {
    cores   = var.vm_specs.master.cpu_cores
    sockets = var.vm_specs.master.cpu_sockets
  }
  
  memory = var.vm_specs.master.memory_mb

  clone      = "ubuntu-template"
  full_clone = true

  disk {
    slot    = "scsi0"
    size    = "${var.vm_specs.master.disk_size_gb}G"
    storage = var.vm_specs.master.disk_storage
    type    = "disk"
    format  = var.vm_specs.master.disk_format
  }

  disk {
    slot    = "ide2"
    storage = var.vm_specs.master.disk_storage
    type    = "cloudinit"
  }

  network {
    id      = 0
    model   = "virtio"
    bridge  = var.network_config.bridge
    macaddr = local.mac_address
  }

  ciuser     = var.cloud_init.user
  sshkeys    = file(pathexpand(var.cloud_init.ssh_key_path))
  ipconfig0  = local.ip_config
  nameserver = join(" ", var.network_config.dns_servers)
  searchdomain = join(" ", var.cloud_init.search_domains)
  
  agent = 1
  scsihw = "virtio-scsi-pci"

  lifecycle {
    ignore_changes = [
      network[0].macaddr,
      vmid
    ]
  }
}

output "master_info" {
  value = {
    name    = proxmox_vm_qemu.k8s_master.name
    vmid    = proxmox_vm_qemu.k8s_master.vmid
    mac     = local.mac_address
    ip      = var.auto_static_ips ? local.master_ip : proxmox_vm_qemu.k8s_master.default_ipv4_address
    ssh     = "ssh -o StrictHostKeyChecking=no ${var.cloud_init.user}@${var.auto_static_ips ? local.master_ip : proxmox_vm_qemu.k8s_master.default_ipv4_address}"
  }
}
