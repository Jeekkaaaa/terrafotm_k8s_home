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

# 1. Создание ПУСТОЙ ВМ с минимальным диском
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  name      = "ubuntu-template"
  node_name = var.target_node
  vm_id     = var.template_vmid
  started   = false  # ВЫКЛЮЧЕННАЯ

  cpu {
    cores   = var.template_specs.cpu_cores
    sockets = var.template_specs.cpu_sockets
  }

  memory {
    dedicated = var.template_specs.memory_mb
  }

  # Минимальный диск для создания ВМ
  disk {
    datastore_id = var.storage_vm
    size         = 1
    interface    = "scsi0"
    file_format  = "raw"
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
      disk[0].size,
      network_device,
    ]
  }
}

# 2. SSH команды для скачивания и импорта Cloud-образа
resource "terraform_data" "download_and_import" {
  depends_on = [proxmox_virtual_environment_vm.ubuntu_template]

  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = regex("//([^:/]+)", var.pm_api_url)[0]
    timeout  = "1200s"  # 20 минут на скачивание + импорт
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=== Шаг 1: Скачивание Cloud-образа ==='",
      "cd /var/lib/vz/template/iso/",
      "if [ ! -f jammy-server-cloudimg-amd64.img ]; then",
      "  echo 'Скачиваем образ...'",
      "  wget -q --show-progress -O jammy-server-cloudimg-amd64.img https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img",
      "else",
      "  echo 'Образ уже существует'",
      "fi",
      
      "echo '=== Шаг 2: Проверяем ВМ ${var.template_vmid} ==='",
      "qm status ${var.template_vmid} || { echo 'ВМ не существует'; exit 1; }",
      
      "echo '=== Шаг 3: Удаляем временный диск ==='",
      "qm set ${var.template_vmid} --delete scsi0 2>/dev/null || true",
      "sleep 2",
      
      "echo '=== Шаг 4: Импортируем Cloud-образ ==='",
      "qm importdisk ${var.template_vmid} /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img ${var.storage_vm} --format raw",
      
      "echo '=== Шаг 5: Настраиваем диск как загрузочный ==='",
      "qm set ${var.template_vmid} --scsi0 ${var.storage_vm}:vm-${var.template_vmid}-disk-0,boot=on",
      "qm set ${var.template_vmid} --boot order=scsi0",
      "qm set ${var.template_vmid} --scsihw virtio-scsi-pci",
      
      "echo '=== Шаг 6: Настраиваем cloud-init ==='",
      "qm set ${var.template_vmid} --ide2 ${var.storage_vm}:cloudinit",
      "qm set ${var.template_vmid} --ciuser ${var.cloud_init.user}",
      "qm set ${var.template_vmid} --sshkeys '${replace(var.ssh_public_key, "'", "'\"'\"'")}'",
      "qm set ${var.template_vmid} --ipconfig0 ip=dhcp",
      "qm set ${var.template_vmid} --nameserver '${join(" ", var.network_config.dns_servers)}'",
      "qm set ${var.template_vmid} --searchdomain '${var.cloud_init.search_domains[0]}'",
      
      "echo '=== Шаг 7: Конвертируем в шаблон ==='",
      "qm template ${var.template_vmid}",
      
      "echo '=== Шаблон ${var.template_vmid} готов! ==='"
    ]
  }
}

output "template_ready" {
  value = "Шаблон ${var.template_vmid} создан и готов к использованию"
  depends_on = [terraform_data.download_and_import]
}
