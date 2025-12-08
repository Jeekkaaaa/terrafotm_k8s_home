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

  # НОВЫЙ СИНТАКСИС ДИСКОВ
  disks {
    scsi {
      scsi0 {
        disk {
          size    = "50G"
          storage = "big_oleg"
          format  = "raw"
        }
      }
    }
    
    ide {
      ide2 {
        cloudinit {
          storage = "big_oleg"
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"
  
  agent = 1

  # Минимальный provisioner
  provisioner "local-exec" {
    command = "echo 'ВМ создана. Проверьте: qm config 4000'"
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
      disks  # Игнорируем изменения дисков
    ]
  }
}

output "vm_info" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "check_commands" {
  value = "Проверьте: qm config 4000 | grep ide2 && qm guest cmd 4000 ping"
}
