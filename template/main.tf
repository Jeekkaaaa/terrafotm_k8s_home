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
}

# 1. Скачиваем образ в runner
resource "terraform_data" "download_image" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Скачивание образа Ubuntu..."
      curl -L -f -o /tmp/jammy-server-cloudimg-amd64.img \
        "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      echo "✅ Образ скачан ($(du -h /tmp/jammy-server-cloudimg-amd64.img | cut -f1))"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f /tmp/jammy-server-cloudimg-amd64.img"
  }
}

# 2. Загружаем в Proxmox через прямой API вызов (минуя провайдер Terraform)
resource "terraform_data" "upload_to_proxmox" {
  depends_on = [terraform_data.download_image]

  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Загрузка образа в Proxmox через API..."
      
      # Извлекаем хост и порт из URL
      PM_HOST=$(echo "${var.pm_api_url}" | sed 's|https://||; s|:8006||')
      PM_TOKEN="${var.pm_api_token_id}=${var.pm_api_token_secret}"
      
      # Получаем ticket для загрузки
      TICKET_RESPONSE=$(curl -s -k -H "Authorization: PVEAPIToken=$PM_TOKEN" \
        "https://$PM_HOST:8006/api2/json/nodes/${var.target_node}/storage/local/upload")
      
      UPLOAD_TICKET=$(echo "$TICKET_RESPONSE" | grep -o '"data":"[^"]*"' | cut -d'"' -f4)
      
      if [ -z "$UPLOAD_TICKET" ]; then
        echo "❌ Не удалось получить upload ticket"
        exit 1
      fi
      
      echo "Загружаем файл с ticket: $UPLOAD_TICKET"
      
      # Загружаем файл
      curl -k -X POST \
        -H "Authorization: PVEAPIToken=$PM_TOKEN" \
        -F "content=iso" \
        -F "filename=@/tmp/jammy-server-cloudimg-amd64.img" \
        "https://$PM_HOST:8006/api2/json/nodes/${var.target_node}/storage/local/upload" \
        --max-time 3600  # 1 час таймаут
      
      echo "✅ Образ загружен в Proxmox через API"
    EOT
  }
}

# 3. Создаем шаблон
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  depends_on = [terraform_data.upload_to_proxmox]

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
  value = "Template ${var.template_vmid} created"
}
