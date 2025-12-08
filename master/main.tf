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
    type    = "scsi"
  }

  # Cloud-Init диск (КРИТИЧЕСКИ ВАЖНО!)
  disk {
    slot     = "ide2"
    storage  = "big_oleg"
    type     = "cdrom"
    size     = "4M"
    format   = "raw"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Cloud-Init настройки
  os_type     = "cloud-init"  # Явно указываем тип ОС
  ciuser      = "ubuntu"
  sshkeys     = file(var.ssh_public_key_path)
  ipconfig0   = "ip=dhcp"
  nameserver  = "8.8.8.8"
  searchdomain = "local"

  # Включаем гостевой агент
  agent = 1

  # Ожидание перед remote-exec (увеличено)
  provisioner "local-exec" {
    command = "echo 'Waiting for Cloud-Init and guest agent...'; sleep 120"
  }

  # Проверка доступности через гостевой агент
  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking VM IP via guest agent..."
      max_attempts=30
      for i in $(seq 1 $max_attempts); do
        if qm guest cmd 4000 ping >/dev/null 2>&1; then
          echo "Guest agent is responding!"
          IP=$(qm guest cmd 4000 network-get-interfaces 2>/dev/null | \
               jq -r '.data[] | ."ip-addresses"[] | select(."ip-address-type"=="ipv4" and ."ip-address"!="127.0.0.1") | ."ip-address"' | head -1)
          if [ -n "$IP" ]; then
            echo "VM IP: $IP"
            echo "$IP" > /tmp/vm-4000-ip.txt
            break
          fi
        fi
        echo "Attempt $i/$max_attempts: Guest agent not ready yet..."
        sleep 10
      done
    EOT
  }

  # Remote-exec с динамическим IP
  provisioner "remote-exec" {
    inline = ["echo 'VM is ready for SSH'"]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = fileexists("/tmp/vm-4000-ip.txt") ? file("/tmp/vm-4000-ip.txt") : "192.168.0.100"
      timeout     = "10m"
    }
  }

  timeouts {
    create = "20m"
    update = "20m"
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      ipconfig0,
      nameserver,
      agent,
      disk[1]  # Игнорируем изменения Cloud-Init диска
    ]
  }
}

# Output для отладки
output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
  description = "IP адрес ВМ через гостевой агент"
  depends_on = [proxmox_vm_qemu.k8s_master]
}
