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

  # Cloud-Init диск (ПРОСТОЙ СИНТАКСИС)
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
  
  # Гостевой агент (число 1, а не строка)
  agent = 1

  # Ожидание Cloud-Init
  provisioner "local-exec" {
    command = "echo 'Ожидание завершения Cloud-Init...'; sleep 180"
  }

  # Проверка SSH (опционально)
  provisioner "remote-exec" {
    inline = ["echo 'VM is ready'"]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
      timeout     = "10m"
    }
    
    on_failure = continue
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

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
}
