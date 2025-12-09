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

# Генерация уникальных значений
locals {
  unique_seed = sha256(timestamp())
  vm_id = 4000 + (parseint(substr(local.unique_seed, 0, 2), 16) % 100)
  
  # Генерация MAC
  mac_part1 = parseint(substr(local.unique_seed, 2, 2), 16) % 256
  mac_part2 = parseint(substr(local.unique_seed, 4, 2), 16) % 256
  mac_part3 = parseint(substr(local.unique_seed, 6, 2), 16) % 256
  mac_address = format("52:54:00:%02x:%02x:%02x", 
    local.mac_part1, local.mac_part2, local.mac_part3)
}

# Основная ВМ
resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-${local.vm_id}"
  target_node = var.target_node
  vmid        = local.vm_id
  description = "Мастер-нода Kubernetes (DHCP)"
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

  # Используем DHCP
  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"
  
  agent = 1
  scsihw = "virtio-scsi-pci"

  # КРИТИЧЕСКИ ВАЖНО: Генерируем уникальный machine-id для DHCP
  provisioner "remote-exec" {
    inline = [
      # Удаляем старый machine-id (если есть)
      "sudo rm -f /etc/machine-id /var/lib/dbus/machine-id",
      
      # Генерируем новый уникальный machine-id
      "sudo dbus-uuidgen --ensure",
      "sudo systemd-machine-id-setup",
      
      # Перезапускаем сеть с новым machine-id
      "sudo systemctl restart systemd-networkd",
      
      # Ждем получения IP
      "sleep 5",
      
      # Показываем новый IP
      "echo 'Новый уникальный machine-id установлен'",
      "echo 'Текущий IP: $(hostname -I)'",
      "echo 'Machine ID: $(cat /etc/machine-id)'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
      timeout     = "10m"
      agent       = false
    }
  }

  lifecycle {
    ignore_changes = [
      network[0].macaddr,
      vmid
    ]
  }
}

# Output переменные
output "vm_info" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
}

output "ssh_command" {
  value = "ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_vm_qemu.k8s_master.default_ipv4_address}"
}
