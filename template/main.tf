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

# Загрузка образа в хранилище для ISO (local)
resource "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.storage_iso
  node_name    = var.target_node
  overwrite    = true
  timeout_upload = 3600
  
  source_file {
    path     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    insecure = true
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
  
  # Диск ВМ в storage_vm (local-lvm)
  disk {
    datastore_id = var.storage_vm
    file_id      = "${var.target_node}/${var.storage_iso}:iso/${proxmox_virtual_environment_file.ubuntu_cloud_image.file_name}"
    size         = var.template_specs.disk_size_gb
    iothread     = var.template_specs.disk_iothread
    interface    = "scsi0"
  }
  
  # Cloud-init диск тоже в storage_vm
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
