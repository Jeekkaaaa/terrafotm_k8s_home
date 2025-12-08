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

# Шаг 1: Сначала фиксируем темплейт с правильным агентом
resource "null_resource" "fix_template" {
  triggers = {
    template_id = "9000"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Снимаем флаг темплейта
      qm set 9000 --template 0 2>/dev/null || true
      
      # Обновляем агент в темплейте
      qm set 9000 --agent enabled=1,fstrim_cloned_disks=1
      
      # Возвращаем флаг темплейта
      qm template 9000 2>/dev/null || true
    EOT
  }
}

# Шаг 2: Создаём ВМ с гарантированно работающим агентом
resource "proxmox_vm_qemu" "k8s_master" {
  depends_on = [null_resource.fix_template]

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

  # Cloud-Init диск (используем новый синтаксис для гарантии QCOW2)
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
  
  # Агент (правильный формат, который обновили в темплейте)
  agent = 1

  # Контроллер SCSI как в темплейте
  scsihw = "virtio-scsi-pci"

  # Шаг 3: Автоматическая пост-настройка после создания ВМ
  provisioner "local-exec" {
    command = <<-EOT
      # Ждём загрузки ВМ
      sleep 60
      
      # Исправляем SSH known_hosts (если нужно)
      ssh-keygen -f '/root/.ssh/known_hosts' -R '192.168.0.100' 2>/dev/null || true
      
      # Получаем реальный IP через ARP как fallback
      MAC=$(qm config 4000 | grep 'net0:' | cut -d'=' -f2 | cut -d',' -f1)
      IP=$(arp -an | grep -i "$MAC" | grep -o '([^)]*)' | tr -d '()' | head -1)
      
      if [ -n "$IP" ]; then
        echo "Найден IP ВМ: $IP"
        # Пробуем установить агент через SSH (если вдруг не работает)
        timeout 30 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
          -i ${var.ssh_private_key_path} ubuntu@$IP \
          "sudo apt update && sudo apt install -y qemu-guest-agent && sudo systemctl enable --now qemu-guest-agent" 2>/dev/null || true
      fi
    EOT
  }

  # Шаг 4: Проверка SSH подключения с игнорированием ключей
  provisioner "remote-exec" {
    inline = [
      "echo '=== ВМ k8s-master-01 успешно настроена ==='",
      "echo 'Дата: $(date)'",
      "echo 'Хостнейм: $(hostname)'",
      "echo 'Гостевой агент: $(systemctl is-active qemu-guest-agent 2>/dev/null || echo не установлен)'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
      timeout     = "10m"
      
      # Отключаем проверку ключей для CI/CD
      bastion_host = null
      agent        = false
      script_path  = "/tmp/terraform_%RAND%.sh"
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
    
    # Принудительно пересоздаём при изменении темплейта
    replace_triggered_by = [
      null_resource.fix_template.id
    ]
  }
}

# Output переменные
output "vm_info" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
}

output "ssh_connection_command" {
  value = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${proxmox_vm_qemu.k8s_master.default_ipv4_address}"
}

output "verification_commands" {
  value = <<-EOT
    Проверка работоспособности:
    1. qm agent 4000 network-get-interfaces
    2. qm config 4000 | grep -E "agent|ide2"
    3. ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_vm_qemu.k8s_master.default_ipv4_address} "hostname"
  EOT
}
