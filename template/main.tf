# ~/gitmnt/terrafotm_k8s_home/template/main.tf
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.56.1"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
  insecure  = true
}

provider "http" {}

# 1. Скачиваем образ через http провайдер (напрямую в runner)
data "http" "ubuntu_image" {
  url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  
  # Повторяем попытку при сбоях
  retry {
    attempts     = 5
    min_delay_ms = 5000
    max_delay_ms = 30000
  }
  
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Не удалось скачать образ Ubuntu. Статус: ${self.status_code}"
    }
  }
}

# 2. Сохраняем скачанный образ во временный файл
resource "local_file" "ubuntu_image_file" {
  filename = "/tmp/jammy-server-cloudimg-amd64.img"
  content_base64 = data.http.ubuntu_image.response_body_base64
  
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f /tmp/jammy-server-cloudimg-amd64.img"
  }
}

# 3. Загружаем локальный файл в Proxmox
resource "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.storage_iso
  node_name    = var.target_node
  overwrite    = true
  
  # Используем локальный файл вместо удаленного URL
  source_file {
    path = "/tmp/jammy-server-cloudimg-amd64.img"
  }
  
  depends_on = [local_file.ubuntu_image_file]
}

# 4. Создаем шаблон (остается без изменений)
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
