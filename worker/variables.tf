# УДАЛЯЕМ ВСЕ строки связанные с SSH из config.auto.tfvars
variable "pm_api_url" {# Proxmox API (передаются че
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type = string
}

# Основные
variable "target_node" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "storage" {
  type = string
}

variable "bridge" {
  type = string
}

# Шаблон
variable "template_vmid" {
  type = number
}

variable "template_specs" {
  type = object({
    cpu_cores     = number
    cpu_sockets   = number
    memory_mb     = number
    disk_size_gb  = number
    disk_iothread = bool
  })
}

# Кластер
variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
  })
}

# VM ID
variable "vmid_ranges" {
  type = object({
    masters = object({ start = number, end = number })
    workers = object({ start = number, end = number })
  })
}

# Спецификации VM
variable "vm_specs" {
  type = object({
    master = object({
      cpu_cores         = number
      cpu_sockets       = number
      memory_mb         = number
      disk_size_gb      = number
      disk_storage      = string
      disk_iothread     = bool
      cloudinit_storage = string
    })
    worker = object({
      cpu_cores         = number
      cpu_sockets       = number
      memory_mb         = number
      disk_size_gb      = number
      disk_storage      = string
      disk_iothread     = bool
      cloudinit_storage = string
    })
  })
}

# Сеть
variable "network_config" {
  type = object({
    subnet       = string
    gateway      = string
    dns_servers  = list(string)
    bridge       = string
  })
}

# Cloud-init
variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
  })
}

# IP
variable "static_ip_base" {
  type = number
}

variable "storage_iso" {
  type = string
}

variable "storage_vm" {
  type = string
}

variable "proxmox_ssh_username" {
  type        = string
  description = "Имя пользователя для SSH подключения к хосту Proxmox"
  default     = ""
}

variable "proxmox_ssh_password" {
  type        = string
  description = "Пароль пользователя для SSH подключения к хосту Proxmox"
  sensitive   = true
  default     = ""
}
