# КЛЮЧЕВОЙ БЛОК: Определение провайдера
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox" # Явно указываем правильный источник
      version = "~> 2.9.14"
    }
  }
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
  clone {
    vm_id = 9000
    full  = true
  }

  # 4. Дополнительные настройки диска
  disk {
    slot    = 0
    size    = "50G"
    storage = "big_oleg"
    type    = "scsi"
  }

  # 5. Сеть
  network {
    id     = 0
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
