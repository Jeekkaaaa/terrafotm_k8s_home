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
  
  # ЯВНО ОТКЛЮЧАЕМ SSH ДЛЯ ИЗБЕЖАНИЯ ОШИБОК АУТЕНТИФИКАЦИИ
  ssh {
    agent = false
  }
}

# Простая проверка через внешний скрипт
resource "terraform_data" "check_image" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = <<-EOT
      echo "Проверка: предполагаем что образ jammy-server-cloudimg-amd64.img уже загружен в Proxmox"
      echo "Если образа нет, загрузите его вручную:"
      echo "wget -O /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img \\"
      echo "  https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      echo "Или через Proxmox UI: Datacenter -> Storage -> local -> ISO Images -> Upload"
    EOT
  }
}

# Создание шаблона
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  depends_on = [terraform_data.check_image]

  name      = "ubuntu-template"
  node_name = var.target_node
  vm_id     = var.template_vmid

  cpu {
    cores   = var.template_specs.cpu_cores
    sockets = var.template_specs.cpu_sockets
  }

  memory {
    dedicated = var.template_specs.memory_mb
  }

  disk {
    datastore_id = var.storage_vm
    file_id      = "${var.storage_iso}:iso/jammy-server-cloudimg-amd64.img"
    size         = var.template_specs.disk_size_gb
    iothread     = var.template_specs.disk_iothread
    interface    = "scsi0"
  }

  initialization {
    datastore_id = var.storage_vm

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
        address = "dhcp"
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

  template = true

  lifecycle {
    ignore_changes = [
      disk[0].size,
      network_device,
    ]
  }
}

output "template_ready" {
  value = "Template ${var.template_vmid} создан (предполагается что образ уже загружен в Proxmox)."
}

output "manual_steps" {
  value = <<-EOT
    Если шаблон не создался из-за отсутствия образа, выполните вручную на Proxmox:
    
    1. Загрузите образ:
       wget -O /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img \\
         https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
    
    2. Запустите workflow 'Create Template' снова.
    
    Или загрузите через Proxmox UI:
    - Datacenter -> Storage -> local -> ISO Images -> Upload
    - Выберите файл или укажите URL: https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
    
    Примечание: Используется VM ID = ${var.template_vmid}
  EOT
}
