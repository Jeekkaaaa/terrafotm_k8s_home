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

  # Системный диск (FIXED: slot как строка, type как "disk")
  disk {
    slot    = "scsi0"
    size    = "50G"
    storage = "big_oleg"
    type    = "disk"
    format  = "raw"
  }

  # Cloud-Init диск (FIXED: slot как "ide2")
  disk {
    slot    = "ide2"
    storage = "big_oleg"
    type    = "cdrom"
    size    = "4M"
    format  = "raw"
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

  # Ожидание Cloud-Init (увеличено до 3 минут)
  provisioner "local-exec" {
    command = "echo 'Ожидание завершения Cloud-Init...'; sleep 180"
  }

  # Проверка IP через гостевой агент (упрощённая версия)
  provisioner "local-exec" {
    command = <<-EOT
      echo "Проверка гостевого агента..."
      max_attempts=30
      IP=""
      
      for i in $(seq 1 $max_attempts); do
        # Пытаемся получить IP через гостевой агент
        if qm guest cmd 4000 ping >/dev/null 2>&1; then
          echo "Гостевой агент доступен на попытке $i"
          
          # Пытаемся получить IP
          AGENT_OUTPUT=$(qm guest cmd 4000 network-get-interfaces 2>/dev/null || echo "")
          if echo "$AGENT_OUTPUT" | grep -q "ip-address"; then
            IP=$(echo "$AGENT_OUTPUT" | jq -r '.data[] | ."ip-addresses"[] | select(."ip-address-type"=="ipv4") | ."ip-address"' | grep -v "127.0.0.1" | head -1)
            if [ -n "$IP" ]; then
              echo "Найден IP через гостевой агент: $IP"
              echo "$IP" > /tmp/vm-4000-ip.txt
              break
            fi
          fi
        fi
        
        # Пробуем через ARP как fallback
        MAC=$(qm config 4000 | grep 'net0:' | sed "s/.*=//" | cut -d',' -f1)
        if [ -n "$MAC" ]; then
          IP=$(arp -an | grep -i "$MAC" | grep -oP '\(\K[^)]+' | head -1)
          if [ -n "$IP" ]; then
            echo "Найден IP через ARP: $IP"
            echo "$IP" > /tmp/vm-4000-ip.txt
            break
          fi
        fi
        
        echo "Попытка $i/$max_attempts: IP не найден, ждём 10 секунд..."
        sleep 10
      done
      
      if [ -z "$IP" ]; then
        echo "Предупреждение: IP не найден ни одним методом"
        echo "remote-exec будет использовать default_ipv4_address"
      else
        echo "Используем IP: $IP"
      fi
    EOT
  }

  # Подключение по SSH
  provisioner "remote-exec" {
    inline = [
      "echo '=== ВМ успешно создана ==='",
      "echo 'Hostname: $(hostname)'",
      "echo 'IP-адреса:'",
      "ip -4 addr show | grep inet"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = fileexists("/tmp/vm-4000-ip.txt") ? trimspace(file("/tmp/vm-4000-ip.txt")) : self.default_ipv4_address
      timeout     = "10m"
    }
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
      # Игнорируем Cloud-Init диск, чтобы не было дрифта
      disk[1]
    ]
  }
}

output "vm_ip_address" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
  description = "IP-адрес ВМ через гостевой агент"
  depends_on = [proxmox_vm_qemu.k8s_master]
}

output "vm_status" {
  value = "Создана: ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}
