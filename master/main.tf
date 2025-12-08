terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

# Генерация случайного MAC-адреса для ВМ
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

# Генерация случайного VMID (проще чем external data source)
resource "random_integer" "vmid" {
  min = 4000
  max = 4099
  keepers = {
    # Изменяем при каждом запуске
    timestamp = timestamp()
  }
}

# Локальный провайдер для поиска свободного VMID (альтернатива)
locals {
  # Используем random VMID - проще и надежнее
  vm_id = random_integer.vmid.result
}

# Основная ВМ
resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-${local.vm_id}"
  target_node = var.target_node
  vmid        = local.vm_id
  description = "Мастер-нода кластера Kubernetes (случайный MAC, случайный VMID)"
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

  # Сеть со случайным MAC-адресом
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    # Случайный MAC-адрес (формат QEMU: 52:54:00:xx:xx:xx)
    macaddr = format("52:54:00:%02x:%02x:%02x",
      random_integer.mac_part1.result,
      random_integer.mac_part2.result,
      random_integer.mac_part3.result)
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

  # Ожидание DHCP
  provisioner "local-exec" {
    command = "echo 'Ждём получения IP через DHCP...' && sleep 60"
  }

  # Обновление агента через SSH
  provisioner "remote-exec" {
    inline = [
      "echo 'Настройка ВМ...'",
      "sudo apt update",
      "sudo apt install -y qemu-guest-agent 2>/dev/null || echo 'Агент уже установлен'",
      "sudo systemctl start qemu-guest-agent 2>/dev/null || true",
      "echo 'Готово. IP: $(hostname -I)'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
      timeout     = "10m"
      bastion_host = null
      agent        = false
    }
    
    on_failure = continue
  }

  # Очистка SSH known_hosts для нового IP
  provisioner "local-exec" {
    command = <<-EOT
      sleep 30
      if [ -n "${self.default_ipv4_address}" ]; then
        ssh-keygen -f '/root/.ssh/known_hosts' -R "${self.default_ipv4_address}" 2>/dev/null || true
        echo "Очищен known_hosts для ${self.default_ipv4_address}"
      fi
    EOT
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      ipconfig0,
      nameserver,
      agent,
      disk[1],
      # Игнорируем изменения MAC после создания
      network[0].macaddr
    ]
    
    # Принудительно пересоздаём при изменении VMID
    create_before_destroy = true
  }
}

# Output переменные
output "vm_info" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "vm_mac" {
  value = proxmox_vm_qemu.k8s_master.network[0].macaddr
  description = "MAC-адрес ВМ"
}

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
  description = "IP адрес через DHCP"
}

output "ssh_command" {
  value = "ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_vm_qemu.k8s_master.default_ipv4_address}"
}
