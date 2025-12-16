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

# 1. Проверяем существует ли образ уже в Proxmox
data "external" "check_image" {
  program = ["bash", "-c", <<-EOT
    # Извлекаем хост и токен из переменных
    PM_HOST=$(echo "$TF_VAR_pm_api_url" | sed 's|https://||; s|:8006||')
    PM_TOKEN="$TF_VAR_pm_api_token_id=$TF_VAR_pm_api_token_secret"
    
    # Проверяем список файлов в хранилище local
    RESPONSE=$(curl -s -k -H "Authorization: PVEAPIToken=$PM_TOKEN" \
      "https://$PM_HOST:8006/api2/json/nodes/${TF_VAR_target_node}/storage/local/content" || echo '[]')
    
    # Ищем наш образ
    if echo "$RESPONSE" | grep -q "jammy-server-cloudimg-amd64.img"; then
      echo '{"exists": "true"}'
    else
      echo '{"exists": "false"}'
    fi
  EOT
]
}

# 2. Скачиваем образ только если его нет
resource "terraform_data" "download_image" {
  count = data.external.check_image.result.exists == "true" ? 0 : 1
  
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

# 3. Загружаем в Proxmox через qm importdisk (локально на Proxmox)
resource "terraform_data" "upload_to_proxmox" {
  count = data.external.check_image.result.exists == "true" ? 0 : 1
  
  depends_on = [terraform_data.download_image]

  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Загрузка образа в Proxmox через qm importdisk..."
      
      # Извлекаем хост
      PM_HOST=$(echo "$TF_VAR_pm_api_url" | sed 's|https://||; s|:8006||')
      
      # Копируем образ на Proxmox
      echo "Копируем файл на Proxmox..."
      scp -o StrictHostKeyChecking=no /tmp/jammy-server-cloudimg-amd64.img \
        root@$PM_HOST:/tmp/jammy-server-cloudimg-amd64.img 2>/dev/null || \
        echo "⚠️  SCP не удался, возможно образ уже на Proxmox"
      
      # Импортируем через qm (работает локально на Proxmox)
      echo "Импортируем образ через qm..."
      ssh -o StrictHostKeyChecking=no root@$PM_HOST << 'SSH_EOF'
        # Проверяем есть ли уже образ
        if [ -f /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img ]; then
          echo "✅ Образ уже существует в Proxmox"
          exit 0
        fi
        
        # Импортируем через временную VM
        echo "Создаем временную VM для импорта..."
        qm create 9999 --name temp-import --memory 128 2>/dev/null || true
        
        # Импортируем диск
        qm importdisk 9999 /tmp/jammy-server-cloudimg-amd64.img local --format qcow2
        
        # Ищем импортированный файл
        IMG_FILE=$(find /var/lib/vz/template/iso/ -name "*jammy*" -type f | head -1)
        
        if [ -z "$IMG_FILE" ]; then
          # Копируем вручную
          cp /tmp/jammy-server-cloudimg-amd64.img /var/lib/vz/template/iso/
          echo "✅ Образ скопирован вручную"
        else
          echo "✅ Образ импортирован: $IMG_FILE"
        fi
        
        # Удаляем временную VM
        qm destroy 9999 --purge 2>/dev/null || true
        
        # Очищаем временный файл
        rm -f /tmp/jammy-server-cloudimg-amd64.img
SSH_EOF
      
      echo "✅ Образ загружен в Proxmox"
    EOT
  }
}

# 4. Создаем шаблон (работает всегда)
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
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
  value = "Template ${var.template_vmid} created. Image exists: ${data.external.check_image.result.exists}"
}

output "image_status" {
  value = data.external.check_image.result.exists == "true" ? "Image already exists, skipping download" : "Downloading and uploading image"
}
