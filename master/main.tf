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

# Основная ВМ
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
  
  # Агент
  agent = 1

  # Контроллер SCSI
  scsihw = "virtio-scsi-pci"

  # Шаг 1: Ожидание загрузки ВМ
  provisioner "local-exec" {
    command = "echo 'ВМ создана. Ожидание загрузки...' && sleep 120"
  }

  # Шаг 2: Поиск IP через Proxmox API
  provisioner "local-exec" {
    command = <<-EOT
      # Пытаемся получить IP через API Proxmox
      echo "Попытка получения IP через API..."
      
      # Используем переменные из CI/CD
      API_URL="${var.pm_api_url}"
      TOKEN_ID="${var.pm_api_token_id}"
      TOKEN_SECRET="${var.pm_api_token_secret}"
      VMID=4000
      
      # Ждем немного перед запросом
      sleep 30
      
      # Запрос к API Proxmox для получения информации о сети
      RESPONSE=$(curl -s -k \
        -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
        "$API_URL/api2/json/nodes/$(echo $API_URL | cut -d'/' -f4)/qemu/$VMID/agent/network-get-interfaces" \
        2>/dev/null || echo "{}")
      
      # Парсим IP из JSON ответа
      IP=$(echo "$RESPONSE" | grep -o '"192\.168\.[0-9]*\.[0-9]*"' | head -1 | tr -d '"')
      
      if [ -n "$IP" ]; then
        echo "IP получен через API: $IP"
        echo "$IP" > /tmp/vm_ip.txt
      else
        echo "IP через API не получен. Пробуем альтернативные методы..."
        
        # Альтернатива: через конфиг ВМ получаем MAC, потом ищем в ARP
        CONFIG=$(curl -s -k \
          -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
          "$API_URL/api2/json/nodes/$(echo $API_URL | cut -d'/' -f4)/qemu/$VMID/config")
        
        MAC=$(echo "$CONFIG" | grep -o 'net0: [^,]*' | cut -d'=' -f2)
        
        if [ -n "$MAC" ]; then
          echo "MAC адрес: $MAC"
          # Здесь мог бы быть вызов скрипта на Proxmox хосте через SSH
          # или использование других методов поиска IP
        fi
        
        echo "IP будет получен позже через SSH/другие методы"
      fi
    EOT
  }

  # Шаг 3: Установка гостевого агента через SSH (если IP найден)
  provisioner "remote-exec" {
    inline = [
      "echo 'Начало установки гостевого агента...'",
      "sudo apt update",
      "sudo apt install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent",
      "echo 'Гостевой агент установлен и запущен'",
      "cloud-init status --wait || echo 'Cloud-init не установлен'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = fileexists("/tmp/vm_ip.txt") ? file("/tmp/vm_ip.txt") : self.default_ipv4_address
      timeout     = "10m"
      # Отключаем проверку ключей для CI/CD
      bastion_host = null
      agent        = false
      script_path  = "/tmp/terraform_%RAND%.sh"
    }
    
    # Если SSH не доступен, продолжаем без ошибки
    on_failure = continue
  }

  # Шаг 4: Финальная проверка
  provisioner "local-exec" {
    command = <<-EOT
      echo "Проверка завершения настройки..."
      
      # Ждем немного после SSH операций
      sleep 30
      
      # Пытаемся проверить агент через API
      API_URL="${var.pm_api_url}"
      TOKEN_ID="${var.pm_api_token_id}"
      TOKEN_SECRET="${var.pm_api_token_secret}"
      
      RESPONSE=$(curl -s -k \
        -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
        "$API_URL/api2/json/nodes/$(echo $API_URL | cut -d'/' -f4)/qemu/4000/agent/network-get-interfaces" \
        2>/dev/null)
      
      if echo "$RESPONSE" | grep -q "ip-address"; then
        echo "✅ Гостевой агент работает!"
        IP=$(echo "$RESPONSE" | grep -o '"192\.168\.[0-9]*\.[0-9]*"' | head -1 | tr -d '"')
        echo "IP ВМ: $IP"
      else
        echo "⚠️ Агент может не работать. Проверьте через VNC/консоль"
        echo "Команды для проверки на Proxmox хосте:"
        echo "  qm config 4000 | grep agent"
        echo "  qm guest cmd 4000 ping"
      fi
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

# Output переменные
output "vm_info" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
  description = "IP адрес через гостевой агент"
}

output "ssh_connection" {
  value = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${proxmox_vm_qemu.k8s_master.default_ipv4_address}"
}

output "verification_steps" {
  value = <<-EOT
    Действия после создания:
    1. Если SSH недоступен - проверьте через VNC консоль
    2. Установите агент вручную если нужно:
       sudo apt update && sudo apt install -y qemu-guest-agent
    3. Обновите формат агента на Proxmox хосте (если требуется):
       qm set 4000 --agent enabled=1,fstrim_cloned_disks=1
  EOT
}

# Переменные
variable "pm_api_url" {
  description = "URL API Proxmox"
  type        = string
}

variable "pm_api_token_id" {
  description = "ID токена API Proxmox"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Секрет токена API Proxmox"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Имя ноды Proxmox"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH ключу"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Путь к приватному SSH ключу"
  type        = string
  sensitive   = true
}
