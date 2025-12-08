# КЛЮЧЕВОЙ БЛОК: Определение провайдера
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0.2-rc06"
    }
  }
}

# Конфигурация провайдера Proxmox
provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

# Создание мастер-ноды Kubernetes
resource "proxmox_vm_qemu" "k8s_master" {
  # 1. Базовые параметры
  name        = "k8s-master-01"
  target_node = var.target_node
  vmid        = 4000
  desc        = "Первая мастер-нода кластера Kubernetes"
  onboot      = true

  # 2. Ресурсы
  cores   = 4
  sockets = 1
  memory  = 8192

  # 3. КЛЮЧЕВОЕ: Клонирование из шаблона (ID 9000)
  clone      = "9000"
  full_clone = true

  # 4. Дополнительные настройки диска
  disk {
    size    = "50G"
    storage = "big_oleg"
    type    = "scsi"
  }

  # 5. Сеть
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # 6. Cloud-Init настройки для этой ВМ
  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"

  # 7. Агент для получения IP
  agent = 1

  # 8. Ожидание готовности ВМ
  provisioner "remote-exec" {
    inline = ["echo 'VM is ready for SSH'"]
    connection {
      type        = "ssh"
      user        = self.ciuser
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
    }
  }

  # 9. Игнорируем изменения Cloud-Init после создания
  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      ipconfig0,
      nameserver
    ]
  }
}
