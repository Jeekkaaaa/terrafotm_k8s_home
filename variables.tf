variable "pm_api_url" { 
  type = string 
  sensitive = true
}

variable "pm_api_token_id" { 
  type = string 
  sensitive = true
}

variable "pm_api_token_secret" { 
  type = string 
  sensitive = true
}

variable "target_node" { 
  type = string 
}

# SSH ключ для ВМ (передается через секреты)
variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}

# SSH доступ к Proxmox (для провайдера)
variable "proxmox_ssh_username" {
  type        = string
  description = "SSH username for Proxmox host"
  default     = ""
}

variable "proxmox_ssh_password" {
  type        = string
  description = "SSH password for Proxmox host"
  sensitive   = true
  default     = ""
}

variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
  })
}

variable "vmid_ranges" {
  type = object({
    masters = object({ start = number, end = number })
    workers = object({ start = number, end = number })
  })
}

variable "vm_specs" {
  type = object({
    master = object({
      cpu_cores          = number
      cpu_sockets        = number
      memory_mb          = number
      disk_size_gb       = number
      disk_storage       = string
      disk_iothread      = bool
      cloudinit_storage  = string
    })
    worker = object({
      cpu_cores          = number
      cpu_sockets        = number
      memory_mb          = number
      disk_size_gb       = number
      disk_storage       = string
      disk_iothread      = bool
      cloudinit_storage  = string
    })
  })
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

variable "network_config" {
  type = object({
    subnet       = string
    gateway      = string
    dns_servers  = list(string)
    bridge       = string
  })
}

variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
  })
}

variable "static_ip_base" { 
  type = number 
}

variable "template_vmid" { 
  type = number 
  default = 9001
}

# Хранилища
variable "storage_iso" {
  type        = string
  description = "Storage for ISO images"
}

variable "storage_vm" {
  type        = string
  description = "Storage for VM disks"
}

# Устаревшие переменные (для обратной совместимости)
variable "storage" { 
  type    = string
  default = ""
}

variable "bridge" { 
  type    = string
  default = ""
}

# Локальная переменная для префикса сети
locals {
  subnet_prefix = split(".", var.network_config.subnet)[0]
}
