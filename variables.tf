# ==================== ОСНОВНЫЕ ПЕРЕМЕННЫЕ ====================
variable "target_node" {
  type    = string
}

variable "template_vmid" {
  type    = number
}

# ==================== КРИТИЧЕСКИЕ ПЕРЕМЕННЫЕ ====================
# Эти переменные ДОЛЖНЫ быть - их используют модули
variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "bridge" {
  type = string
}

variable "storage_iso" {
  type = string
}

variable "storage_vm" {
  type = string
}

# ==================== КЛАСТЕР КОНФИГ ====================
variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
    environment   = string
  })
}

# ==================== VM ID ДИАПАЗОНЫ ====================
variable "vmid_ranges" {
  type = object({
    masters = object({ start = number, end = number })
    workers = object({ start = number, end = number })
  })
}

# ==================== СПЕЦИФИКАЦИИ VM ====================
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

# ==================== СЕТЬ ====================
variable "network_config" {
  type = object({
    subnet      = string
    gateway     = string
    dns_servers = list(string)
    bridge      = string
  })
}

# ==================== CLOUD-INIT ====================
variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
  })
}

# ==================== KUBERNETES ====================
variable "kubernetes_config" {
  type = object({
    version          = string
    pod_network_cidr = string
    service_cidr     = string
    cri_socket       = string
    ha_config = object({
      enabled          = bool
      load_balancer_ip = string
      keepalived_vrid  = number
    })
    components = object({
      coredns_version = string
      etcd_version    = string
    })
  })
}

# ==================== CNI ====================
variable "cni_config" {
  type = object({
    plugin       = string
    version      = string
    manifest_url = string
    ipip_mode    = string
    nat_outgoing = bool
  })
}

# ==================== АДДОНЫ ====================
variable "addons_config" {
  type = object({
    ingress = object({
      enabled    = bool
      controller = string
      version    = string
      helm_chart = string
    })
    metallb = object({
      enabled  = bool
      version  = string
      ip_range = string
    })
    storage = object({
      enabled     = bool
      provisioner = string
      version     = string
    })
    monitoring = object({
      enabled    = bool
      prometheus = string
      grafana    = string
    })
    helm = object({
      enabled = bool
      version = string
    })
  })
}

# ==================== WORKFLOW ====================
variable "workflow_config" {
  type = object({
    ip_search = object({
      range_start = number
      range_end   = number
      buffer_ips  = number
    })
    timeouts = object({
      template_create = number
      vm_boot         = number
      ssh_ready       = number
      cluster_init    = number
      cni_install     = number
      addons_install  = number
    })
    retries = object({
      ssh_connection = number
      api_ready      = number
      node_join      = number
    })
  })
}

# ==================== ШАБЛОН ====================
variable "template_specs" {
  type = object({
    cpu_cores    = number
    cpu_sockets  = number
    memory_mb    = number
    disk_size_gb = number
    disk_iothread = bool
  })
}

# ==================== IP АДРЕСАЦИЯ ====================
variable "auto_static_ips" {
  type = bool
}

variable "static_ip_base" {
  type = number
}

# ==================== PROXMOX API (ЧЕРЕЗ СЕКРЕТЫ) ====================
variable "pm_api_url" {
  type      = string
  sensitive = true
}

variable "pm_api_token_id" {
  type      = string
  sensitive = true
}

variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}

# ==================== ANSIBLE РЕПОЗИТОРИЙ ====================
variable "ansible_repo_url" {
  type = string
}
