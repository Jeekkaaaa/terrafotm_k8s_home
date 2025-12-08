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

# Генерация уникального MAC и VMID
locals {
  seed = timestamp()
  vm_id = 4100 + (parseint(formatdate("SS", local.seed), 10) % 100)
  
  # Исправлено: mac_hex должна быть внутри local
  mac_hex = format("%06x", parseint(substr(sha256(local.seed), 0, 6), 16))
  
  # Теперь правильно ссылаемся на local.mac_hex
  mac_address = "52:54:00:${substr(local.mac_hex, 0, 2)}:${substr(local.mac_hex, 2, 2)}:${substr(local.mac_hex, 4, 2)}"
}

# Основная ВМ
resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-${local.vm_id}"
  target_node = var.target_node
  vmid        = local.vm_id
  description = "K8s Master - DHCP с перезагрузкой"
  start_at_node_boot = true

  cpu {
    cores   = 4
    sockets = 1
  }
  
  memory  = 8192

  clone      = "ubuntu-template"
  full_clone = true

  disk {
    slot    = "scsi0"
    size    = "50G"
    storage = "big_oleg"
    type    = "disk"
    format  = "raw"
  }

  disk {
    slot    = "ide2"
    storage = "big_oleg"
    type    = "cloudinit"
  }

  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    macaddr = local.mac_address
  }

  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"
  
  agent = 1
  scsihw = "virtio-scsi-pci"

  # Ждем получения первого IP
  provisioner "local-exec" {
    command = "echo 'Ожидание первого IP...' && sleep 30"
  }

  # ПЕРЕЗАГРУЗКА ДЛЯ НОВОГО IP
  provisioner "local-exec" {
    command = <<-EOT
      echo "Перезагрузка ВМ ${self.vmid}..."
      qm reboot ${self.vmid}
      echo "Ждем 40 секунд..."
      sleep 40
    EOT
  }

  # Проверяем IP после перезагрузки
  provisioner "remote-exec" {
    inline = [
      "echo 'ВМ перезагружена. Текущий IP: $(hostname -I)'",
      "sudo systemctl enable --now qemu-guest-agent"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
      timeout     = "5m"
    }
  }

  lifecycle {
    ignore_changes = [
      network[0].macaddr,
      vmid
    ]
  }
}

# Output
output "vm_info" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
}

output "ssh_command" {
  value = "ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_vm_qemu.k8s_master.default_ipv4_address}"
}
