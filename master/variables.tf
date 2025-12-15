# ============ СЕКРЕТЫ (без значений по умолчанию) ============
variable "pm_api_url" {
  type        = string
  sensitive   = true
}

variable "pm_api_token_id" {
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  type        = string
  sensitive   = true
}

# ============ ОСНОВНЫЕ ПЕРЕМЕННЫЕ (с значениями по умолчанию из common) ============
variable "target_node" {
  type    = string
  default = "pve"
}

variable "ssh_public_key_path" {
  type    = string
  default = "/root/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  type    = string
  default = "/root/.ssh/id_ed25519"
}

variable "network_config" {
  type = object({
    subnet       = string
    gateway      = string
    dns_servers  = list(string)
    bridge       = string
    dhcp_start   = number
    dhcp_end     = number
  })
  default = {
    subnet       = "192.168.0.0/24"
    gateway      = "192.168.0.1"
    dns_servers  = ["8.8.8.8", "8.8.4.4"]
    bridge       = "vmbr0"
    dhcp_start   = 100
    dhcp_end     = 200
  }
}

variable "vmid_ranges" {
  type = object({
    masters = object({ start = number, end = number })
    workers = object({ start = number, end = number })
  })
  default = {
    masters = { start = 4100, end = 4199 }
    workers = { start = 4200, end = 4299 }
  }
}

variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
  })
  default = {
    masters_count = 1
    workers_count = 2
    cluster_name  = "k8s-cluster"
    domain        = "local"
  }
}

variable "auto_static_ips" {
  type    = bool
  default = false
}

variable "static_ip_base" {
  type    = number
  default = 100
}

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

variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
  })
  default = {
    user           = "ubuntu"
    search_domains = ["local"]
  }
}
