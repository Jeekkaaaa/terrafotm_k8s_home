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

# Локальные переменные для генерации уникальных значений
locals {
  # Используем хеш от timestamp для уникальности
  unique_seed = sha256(timestamp())
  
  # VMID: 4000-4099 на основе хеша
  vm_id = 4000 + (parseint(substr(local.unique_seed, 0, 2), 16) % 100)
  
  # Генерация MAC на основе хеша
  mac_part1 = parseint(substr(local.unique_seed, 2, 2), 16) % 256
  mac_part2 = parseint(substr(local.unique_seed, 4, 2), 16) % 256
  mac_part3 = parseint(substr(local.unique_seed, 6, 2), 16) % 256
  
  # Форматированный MAC
  mac_address = format("52:54:00:%02x:%02x:%02x", 
    local.mac_part1, local.mac_part2, local.mac_part3)
}

# Основная ВМ
resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-${local.vm_id}"
  target_node = var.target_node
  vmid        = local.vm_id
  description = "Мастер-нода кластера Kubernetes (динамический MAC: ${local.mac_address})"
  start_at_node_boot = true

  cpu {
    cores   = 4
    sockets = 1
  }
  
  memory  = 8192

  clone      = "ubuntu-template"
  full_clone = true

  # Системный диск
  disk {
    slot    = "scsi0"
    size    = "50G"
    storage = "big_oleg"
    type    = "disk"
    format  = "raw"
  }

  # Cloud-Init диск
  disk {
    slot    = "ide2"
    storage = "big_oleg"
    type    = "cloudinit"
  }

  # Сеть с динамическим MAC-адресом
  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    macaddr = local.mac_address
  }

  # Cloud-Init настройки
  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"
  
  # Агент
  agent = 1

  # Контроллер SCSI
  scsihw = "virtio-scsi-pci"

  # Ожидание DHCP (уменьшил время)
  provisioner "local-exec" {
    command = "echo 'Ожидание получения IP через DHCP...' && sleep 30"
  }

  # Обновление агента через SSH
  provisioner "remote-exec" {
    inline = [
      "echo 'Настройка ВМ завершена'",
      "sudo systemctl start qemu-guest-agent 2>/dev/null || true"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
      timeout     = "5m"
      agent       = false
    }
    
    on_failure = continue
  }

  timeouts {
    create = "15m"
    update = "15m"
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      ipconfig0,
      nameserver,
      agent,
      disk[1],
      network[0].macaddr,
      vmid
    ]
    
    # Нужно пересоздать при изменении VMID или MAC
    create_before_destroy = true
  }
}

# Output переменные
output "vm_info" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "vm_mac" {
  value = proxmox_vm_qemu.k8s_master.network[0].macaddr
}

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
}

output "ssh_command" {
  value = "ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_vm_qemu.k8s_master.default_ipv4_address}"
}
