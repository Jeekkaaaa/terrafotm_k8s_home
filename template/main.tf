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

# Скачивание образа через null_resource
resource "null_resource" "download_image" {
  triggers = {
    always_run = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Скачивание облачного образа Ubuntu..."
      if ! wget -q --show-progress -O /tmp/jammy-server-cloudimg-amd64.img \
        "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"; then
        echo "Ошибка скачивания, пробуем curl..."
        curl -L -o /tmp/jammy-server-cloudimg-amd64.img \
          "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      fi
      echo "✅ Образ скачан ($(du -h /tmp/jammy-server-cloudimg-amd64.img | cut -f1))"
    EOT
  }
}

# Загрузка в Proxmox
resource "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  depends_on = [null_resource.download_image]
  
  content_type = "iso"
  datastore_id = var.storage_iso
  node_name    = var.target_node
  overwrite    = true
  timeout_upload = 3600
  
  source_file {
    path = "/tmp/jammy-server-cloudimg-amd64.img"
  }
}

# ... остальная конфигурация шаблона без изменений
