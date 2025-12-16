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
  
  # ОТКЛЮЧАЕМ SSH - используем только API
  ssh {
    agent = false
  }
}

# Проверка и скачивание образа
resource "terraform_data" "check_and_download_image" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Проверка существования образа в Proxmox..."

      PM_HOST=$(echo "$TF_VAR_pm_api_url" | sed 's|https://||; s|:8006||')
      PM_TOKEN="$TF_VAR_pm_api_token_id=$TF_VAR_pm_api_token_secret"
      TARGET_NODE="$TF_VAR_target_node"

      # Пытаемся проверить через API Proxmox
      API_CHECK=$(curl -s -k -f -H "Authorization: PVEAPIToken=$PM_TOKEN" \
        "https://$PM_HOST:8006/api2/json/nodes/$TARGET_NODE/storage/local/content" 2>/dev/null || echo '{"data":[]}')

      if echo "$API_CHECK" | grep -q "jammy-server-cloudimg-amd64.img"; then
        echo "✅ Образ уже существует в хранилище Proxmox. Пропускаем загрузку."
        exit 0
      else
        echo "⚠️ Образ не найден в хранилище Proxmox (или ошибка API)."
        echo "Скачивание образа Ubuntu..."
        curl -L -f -o /tmp/jammy-server-cloudimg-amd64.img \
          "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
        echo "✅ Образ скачан ($(du -h /tmp/jammy-server-cloudimg-amd64.img | cut -f1))"
        
        # ЗАГРУЗКА ЧЕРЕЗ API PROXMOX
        echo "Загрузка образа в Proxmox через API..."
        
        # Получаем ticket для загрузки
        UPLOAD_URL="https://$PM_HOST:8006/api2/json/nodes/$TARGET_NODE/storage/local/upload"
        
        # Делаем загрузку с большим таймаутом
        curl -k -X POST \
          -H "Authorization: PVEAPIToken=$PM_TOKEN" \
          -F "content=iso" \
          -F "filename=@/tmp/jammy-server-cloudimg-amd64.img" \
          "$UPLOAD_URL" \
          --max-time 7200  # 2 часа таймаут
        
        echo "✅ Образ загружен в Proxmox!"
        
        # Очищаем временный файл
        rm -f /tmp/jammy-server-cloudimg-amd64.img
      fi
    EOT
  }
}

# Создание шаблона
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  depends_on = [terraform_data.check_and_download_image]

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
  value = "Template ${var.template_vmid} готов к работе (образ проверен/скачан/загружен)."
}
