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
  
  ssh {
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
  }
}

# 1. Автозагрузка Cloud-образа в Proxmox
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.storage_iso
  node_name    = var.target_node
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  overwrite    = true
}

# 2. Создание ВМ с МИНИМАЛЬНЫМ диском (1GB) и выключенной
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  name      = "ubuntu-template"
  node_name = var.target_node
  vm_id     = var.template_vmid
  started   = false  # КРИТИЧЕСКИ ВАЖНО: создаем выключенной

  cpu {
    cores   = var.template_specs.cpu_cores
    sockets = var.template_specs.cpu_sockets
  }

  memory {
    dedicated = var.template_specs.memory_mb
  }

  # ВРЕМЕННЫЙ диск 1GB (удалится при импорте)
  disk {
    datastore_id = var.storage_vm
    size         = 1
    interface    = "scsi0"
    iothread     = true
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

  template = false

  lifecycle {
    ignore_changes = [
      disk[0].size,  # Размер изменится при импорте
      network_device,
    ]
  }
}

# 3. Импорт Cloud-образа как диска ВМ через SSH
resource "terraform_data" "import_cloud_image" {
  depends_on = [
    proxmox_virtual_environment_download_file.ubuntu_cloud_image,
    proxmox_virtual_environment_vm.ubuntu_template
  ]

  triggers_replace = {
    vm_id = var.template_vmid
  }

  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = regex("//([^:/]+)", var.pm_api_url)[0]
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Импортируем Cloud-образ как диск для ВМ ${var.template_vmid}...'",
      # Удаляем временный диск
      "qm set ${var.template_vmid} --delete scsi0",
      # Импортируем Cloud-образ
      "qm importdisk ${var.template_vmid} /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img ${var.storage_vm}",
      "qm set ${var.template_vmid} --scsi0 ${var.storage_vm}:vm-${var.template_vmid}-disk-0",
      "qm set ${var.template_vmid} --boot order=scsi0",
      "qm set ${var.template_vmid} --scsihw virtio-scsi-pci",
      "qm set ${var.template_vmid} --ide2 ${var.storage_vm}:cloudinit",
      "qm set ${var.template_vmid} --serial0 socket --vga serial0",
      "qm set ${var.template_vmid} --agent enabled=1"
    ]
  }
}

# 4. Конвертация ВМ в шаблон
resource "terraform_data" "convert_to_template" {
  depends_on = [terraform_data.import_cloud_image]

  triggers_replace = {
    vm_id = var.template_vmid
  }

  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = regex("//([^:/]+)", var.pm_api_url)[0]
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Конвертируем ВМ ${var.template_vmid} в шаблон...'",
      "qm template ${var.template_vmid}"
    ]
  }
}

output "template_ready" {
  value = "Template ${var.template_vmid} создан из Cloud-образа."
  depends_on = [terraform_data.convert_to_template]
}
