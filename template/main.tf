terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

# Загружаем облачный образ Ubuntu
resource "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.storage
  node_name    = var.target_node

  source_file {
    path = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  }
}

# Создаем ВМ из образа
resource "proxmox_vm_qemu" "ubuntu_template" {
  depends_on = [proxmox_virtual_environment_file.ubuntu_cloud_image]
  
  name        = "ubuntu-template"
  vmid        = var.template_vmid
  target_node = var.target_node
  desc        = "Ubuntu 22.04 Cloud-Init Template"
  
  # Используем cloud-init образ
  clone = null
  
  cpu {
    cores   = var.template_specs.cpu_cores
    sockets = var.template_specs.cpu_sockets
  }
  
  memory = var.template_specs.memory_mb
  
  # Основной диск
  disk {
    slot     = 0
    type     = "scsi"
    storage  = var.storage
    size     = "${var.template_specs.disk_size_gb}G"
    iothread = var.template_specs.disk_iothread
  }
  
  # Cloud-init диск
  disk {
    slot    = 2
    type    = "cloudinit"
    storage = var.storage
  }
  
  # Сеть
  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }
  
  # Cloud-init
  ciuser       = var.cloud_init.user
  searchdomain = join(" ", var.cloud_init.search_domains)
  sshkeys      = var.ssh_public_key
  
  # Загрузка
  boot      = "order=scsi0"
  bootdisk  = "scsi0"
  scsihw    = "virtio-scsi-pci"
  agent     = 1
  os_type   = "cloud-init"
  
  lifecycle {
    ignore_changes = [
      disk[0].size,
      network,
    ]
  }
}

# Конвертируем в шаблон (просто ждем, т.к. qm не доступен в CI)
resource "null_resource" "wait_and_convert" {
  depends_on = [proxmox_vm_qemu.ubuntu_template]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Template VM ${var.template_vmid} created."
      echo "Note: Manual conversion to template may be needed in Proxmox UI"
      echo "or run: qm set ${var.template_vmid} --template 1"
    EOT
  }
}
