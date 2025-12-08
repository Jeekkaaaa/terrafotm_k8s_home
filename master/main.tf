terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-01"
  target_node = var.target_node
  vmid        = 4000
  description = "Первая мастер-нода кластера Kubernetes"
  start_at_node_boot = true

  cpu {
    cores   = 4
    sockets = 1
  }
  
  memory  = 8192

  clone      = "ubuntu-template"
  full_clone = true

  # Системный диск
  disk {
    slot    = "scsi0"
    size    = "50G"
    storage = "big_oleg"
    type    = "disk"
    format  = "raw"
  }

  # Cloud-Init диск
  disk {
    slot    = "ide2"
    storage = "big_oleg"
    type    = "cloudinit"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Cloud-Init настройки
  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"
  
  # Включаем гостевой агент
  agent = 1

  # Ожидание Cloud-Init
  provisioner "local-exec" {
    command = "echo 'Ожидание завершения Cloud-Init...'; sleep 300"
  }

  # Проверка создания ВМ
  provisioner "remote-exec" {
    inline = [
      "echo '=== ВМ k8s-master-01 успешно создана ==='",
      "echo 'Дата: $(date)'",
      "echo 'Проверка сети:'",
      "ip -4 addr show"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
      timeout     = "10m"
    }
    
    on_failure = continue
  }

  # Финальное сообщение
  provisioner "local-exec" {
    command = <<-EOT
      echo "========================================="
      echo "ВМ создана: k8s-master-01 (VMID: 4000)"
      echo "Проверьте в Proxmox:"
      echo "1. qm config 4000 | grep ide2"
      echo "2. qm guest cmd 4000 ping"
      echo "3. qm guest cmd 4000 network-get-interfaces"
      echo "========================================="
    EOT
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      ipconfig0,
      nameserver,
      agent,
      disk[1]
    ]
  }
}

output "vm_status" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} создана (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "check_commands" {
  value = <<-EOT
    Проверка после создания:
    1. Проверить Cloud-Init: qm config 4000 | grep ide2
    2. Проверить гостевой агент: qm guest cmd 4000 ping
    3. Проверить IP: qm guest cmd 4000 network-get-interfaces
    4. Если агент не работает: установить в ВМ qemu-guest-agent
  EOT
}
