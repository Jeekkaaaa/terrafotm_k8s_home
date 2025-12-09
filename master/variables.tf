# common/variables.tf - ОБЩИЕ ПЕРЕМЕННЫЕ ДЛЯ ВСЕХ МОДУЛЕЙ

# ==================== ПОДКЛЮЧЕНИЕ PROXMOX ====================
variable "proxmox_config" {
  type = object({
    api_url      = string
    token_id     = string
    token_secret = string
    node         = string
    storage      = string
    insecure     = bool
  })
  description = "Настройки подключения к Proxmox"
  sensitive   = true
}

# ==================== СЕТЕВЫЕ НАСТРОЙКИ ====================
variable "network_config" {
  type = object({
    subnet       = string
    gateway      = string
    dns_servers  = list(string)
    bridge       = string
    dhcp_start   = number
    dhcp_end     = number
  })
  description = "Сетевые настройки"
  default = {
    subnet       = "192.168.0.0/24"
    gateway      = "192.168.0.1"
    dns_servers  = ["8.8.8.8", "8.8.4.4"]
    bridge       = "vmbr0"
    dhcp_start   = 100
    dhcp_end     = 200
  }
}

# ==================== ДИАПАЗОНЫ VMID ====================
variable "vmid_ranges" {
  type = object({
    masters = object({
      start = number
      end   = number
    })
    workers = object({
      start = number
      end   = number
    })
  })
  description = "Диапазоны VMID для разных типов нод"
  default = {
    masters = {
      start = 4000
      end   = 4099
    }
    workers = {
      start = 4200
      end   = 4299
    }
  }
}

# ==================== НАСТРОЙКИ КЛАСТЕРА ====================
variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
  })
  description = "Настройки кластера Kubernetes"
  default = {
    masters_count = 1
    workers_count = 2
    cluster_name  = "k8s-cluster"
    domain        = "local"
  }
}

# ==================== РЕЖИМ IP АДРЕСАЦИИ ====================
variable "auto_static_ips" {
  type        = bool
  default     = false
  description = "Использовать автоматические статические IP на основе VMID"
}

variable "static_ip_base" {
  type        = number
  default     = 100
  description = "Базовый номер для статических IP (например 100 = 192.168.0.100)"
}

# ==================== ХАРДВЕРНЫЕ СПЕЦИФИКАЦИИ ====================
variable "vm_specs" {
  type = object({
    master = object({
      cpu_cores    = number
      cpu_sockets  = number
      memory_mb    = number
      disk_size_gb = number
      disk_storage = string
      disk_format  = string
    })
    worker = object({
      cpu_cores    = number
      cpu_sockets  = number
      memory_mb    = number
      disk_size_gb = number
      disk_storage = string
      disk_format  = string
    })
  })
  description = "Хардверные спецификации для ВМ"
  default = {
    master = {
      cpu_cores    = 4
      cpu_sockets  = 1
      memory_mb    = 8192
      disk_size_gb = 50
      disk_storage = "local-lvm"
      disk_format  = "raw"
    }
    worker = {
      cpu_cores    = 2
      cpu_sockets  = 1
      memory_mb    = 4096
      disk_size_gb = 30
      disk_storage = "local-lvm"
      disk_format  = "raw"
    }
  }
}

# ==================== CLOUD-INIT НАСТРОЙКИ ====================
variable "cloud_init" {
  type = object({
    user           = string
    ssh_key_path   = string
    ssh_priv_path  = string
    search_domains = list(string)
  })
  description = "Настройки Cloud-Init"
  default = {
    user           = "ubuntu"
    ssh_key_path   = "~/.ssh/id_rsa.pub"
    ssh_priv_path  = "~/.ssh/id_rsa"
    search_domains = ["local"]
  }
}

# ==================== ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ ====================
variable "tags" {
  type        = map(string)
  description = "Теги для ресурсов"
  default = {
    environment = "development"
    managed_by  = "terraform"
    project     = "kubernetes"
  }
}

# ==================== ЛОКАЛЬНЫЕ ПЕРЕМЕННЫЕ ====================
locals {
  # Форматирование SSH ключа для Proxmox (заменяем пробелы на %20)
  formatted_ssh_key = replace(
    file(pathexpand(var.cloud_init.ssh_key_path)),
    " ",
    "%20"
  )
  
  # Полные пути к SSH ключам
  ssh_public_key_content  = file(pathexpand(var.cloud_init.ssh_key_path))
  ssh_private_key_path    = pathexpand(var.cloud_init.ssh_priv_path)
  
  # Префикс для MAC адресов
  mac_prefix = "52:54:00"
}
