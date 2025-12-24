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

# 1. Очистка старого
resource "terraform_data" "cleanup_old_template" {
  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = regex("//([^:/]+)", var.pm_api_url)[0]
  }

  provisioner "remote-exec" {
    inline = [
      "qm destroy ${var.template_vmid} --purge 2>/dev/null || true",
      "sleep 2"
    ]
  }
}

# 2. Создание шаблона с Cloud-образом
resource "terraform_data" "create_proper_template" {
  depends_on = [terraform_data.cleanup_old_template]

  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = regex("//([^:/]+)", var.pm_api_url)[0]
    timeout  = "1800s"
  }

  provisioner "remote-exec" {
    inline = [
      "set -ex",
      
      "# 1. Скачиваем образ",
      "cd /var/lib/vz/template/iso/",
      "[ -f jammy-server-cloudimg-amd64.img ] || wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img",
      
      "# 2. Создаем ВМ с Cloud-образом",
      "qm create ${var.template_vmid} --name ubuntu-template --memory ${var.template_specs.memory_mb} --cores ${var.template_specs.cpu_cores} --net0 virtio,bridge=${var.network_config.bridge}",
      
      "# 3. Импортируем Cloud-образ",
      "qm importdisk ${var.template_vmid} jammy-server-cloudimg-amd64.img ${var.storage_vm} --format raw",
      
      "# 4. Подключаем диск",
      "qm set ${var.template_vmid} --scsi0 ${var.storage_vm}:vm-${var.template_vmid}-disk-0",
      "qm set ${var.template_vmid} --boot order=scsi0",
      "qm set ${var.template_vmid} --scsihw virtio-scsi-pci",
      
      "# 5. Настраиваем UEFI загрузку",
      "qm set ${var.template_vmid} --bios ovmf",
      "qm set ${var.template_vmid} --machine pc-q35-8.1",
      "qm set ${var.template_vmid} --efidisk0 ${var.storage_vm}:1,format=raw,efitype=4m,pre-enrolled-keys=0",
      
      "# 6. Настраиваем cloud-init",
      "qm set ${var.template_vmid} --ide2 ${var.storage_vm}:cloudinit",
      "qm set ${var.template_vmid} --ciuser ${var.cloud_init.user}",
      
      "# 7. Добавляем SSH ключ через временный файл",
      "echo '${var.ssh_public_key}' > /tmp/ssh_key_${var.template_vmid}.txt",
      "qm set ${var.template_vmid} --sshkeys /tmp/ssh_key_${var.template_vmid}.txt",
      "rm -f /tmp/ssh_key_${var.template_vmid}.txt",
      
      "# 8. Настройки сети",
      "qm set ${var.template_vmid} --ipconfig0 ip=dhcp",
      "qm set ${var.template_vmid} --nameserver '${join(" ", var.network_config.dns_servers)}'",
      "qm set ${var.template_vmid} --searchdomain '${var.cloud_init.search_domains[0]}'",
      
      "# 9. Устанавливаем размер диска",
      "qm resize ${var.template_vmid} scsi0 ${var.template_specs.disk_size_gb}G",
      
      "# 10. Конвертируем в шаблон",
      "qm template ${var.template_vmid}",
      
      "# 11. Проверяем что ключ добавлен",
      "echo 'Проверяем SSH ключ в шаблоне:'",
      "qm config ${var.template_vmid} | grep sshkeys",
      
      "echo '✅ Шаблон ${var.template_vmid} создан с UEFI загрузкой и SSH ключом'"
    ]
  }
}

output "template_ready" {
  value = "Template ${var.template_vmid} created with UEFI boot and SSH key"
}
