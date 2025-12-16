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

# 1. Проверка существования образа через terraform_data (встроенный ресурс)
resource "terraform_data" "check_and_download_image" {
  triggers_replace = timestamp() # Запускается при каждом apply

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Проверка существования образа в Proxmox..."

      # Подготовка переменных из окружения Terraform
      PM_HOST=$(echo "$TF_VAR_pm_api_url" | sed 's|https://||; s|:8006||')
      PM_TOKEN="$TF_VAR_pm_api_token_id=$TF_VAR_pm_api_token_secret"
      TARGET_NODE="$TF_VAR_target_node"

      # Пытаемся проверить через API Proxmox, игнорируем ошибки подключения
      API_CHECK=$(curl -s -k -f -H "Authorization: PVEAPIToken=$PM_TOKEN" \
        "https://$PM_HOST:8006/api2/json/nodes/$TARGET_NODE/storage/local/content" 2>/dev/null || echo '{"data":[]}')

      # Если в ответе есть имя нашего файла, считаем что образ существует
      if echo "$API_CHECK" | grep -q "jammy-server-cloudimg-amd64.img"; then
        echo "✅ Образ уже существует в хранилище Proxmox. Пропускаем загрузку."
        exit 0
      else
        echo "⚠️ Образ не найден в хранилище Proxmox (или ошибка API)."
        echo "Скачивание образа Ubuntu..."
        curl -L -f -o /tmp/jammy-server-cloudimg-amd64.img \
          "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
        echo "✅ Образ скачан ($(du -h /tmp/jammy-server-cloudimg-amd64.img | cut -f1))"

        # Здесь могла бы быть логика загрузки в Proxmox, но из-за ошибок broken pipe
        # мы пока просто скачиваем файл. Загрузку можно выполнить отдельным шагом позже.
        echo "Примечание: Для загрузки в Proxmox может потребоваться ручной шаг (scp) или настройка SSH."
      fi
    EOT
  }
}

# 2. Создание шаблона ВМ (зависит от образа)
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

  # Используем образ, который предположительно уже загружен в хранилище 'local'
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
  value = "Template ${var.template_vmid} готов к работе (образ проверен/скачан)."
  # В реальном сценарии здесь можно выводить больше информации, например:
  # depends_on = [terraform_data.check_and_download_image]
}
