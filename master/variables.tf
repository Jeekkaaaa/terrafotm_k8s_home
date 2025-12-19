variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type = string
}

variable "target_node" {
  type    = string
  default = "pve-k8s"
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

variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
  })
}

variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
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

variable "static_ip_base" {
  type = number
}

variable "ssh_public_key" {
  type = string
}

variable "storage" {
  type    = string
  default = "local-lvm"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
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
