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

variable "template_vmid" {
  type    = number
  default = 9000
}

variable "ssh_public_key" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "ssh_private_key_path" {
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

variable "template_specs" {
  type = object({
    cpu_cores     = number
    cpu_sockets   = number
    memory_mb     = number
    disk_size_gb  = number
    disk_iothread = bool
  })
}

variable "auto_static_ips" {
  type = bool
}

variable "static_ip_base" {
  type = number
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

variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
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

variable "vmid_ranges" {
  type = object({
    masters = object({ start = number, end = number })
    workers = object({ start = number, end = number })
  })
}
