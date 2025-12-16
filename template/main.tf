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

# Скачивание образа через terraform_data (встроенный ресурс, не требует провайдера)
resource "terraform_data" "download_image" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Скачивание образа Ubuntu..."
      if ! wget -q --show-progress -O /tmp/jammy-server-cloudimg-amd64.img \
        "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"; then
        echo "Ошибка wget, пробуем curl..."
        curl -L -f -o /tmp/jammy-server-cloudimg-amd64.img \
          "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      fi
      echo "✅ Образ скачан ($(du -h /tmp/jammy-server-cloudimg-amd64.img | cut -f1))"
    EOT
  }

  # ДОБАВЛЕННАЯ КОМАНДА: Очистка временного файла при destroy
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f /tmp/jammy-server-cloudimg-amd64.img"
  }
}

# Загрузка локального файла в Proxmox
resource "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  depends_on = [terraform_data.download_image]

  content_type = "iso"
  datastore_id = var.storage_iso
  node_name    = var.target_node
  overwrite    = true
  timeout_upload = 3600

  source_file {
    path = "/tmp/jammy-server-cloudimg-amd64.img"
  }
}

# Создание шаблона
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  depends_on = [proxmox_virtual_environment_file.ubuntu_cloud_image]

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
    file_id      = "${var.target_node}/${var.storage_iso}:iso/jammy-server-cloudimg-amd64.img"
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
