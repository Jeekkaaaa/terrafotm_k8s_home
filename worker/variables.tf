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
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "ssh_private_key_path" {
  type = string
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

variable "auto_static_ips" {
  type = bool
}

variable "static_ip_base" {
  type = number
}

variable "template_vmid" {
  type = number
}

variable "storage" {
  type = string
}

variable "bridge" {
  type = string
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

variable "ssh_public_key" {
  type = string
}
