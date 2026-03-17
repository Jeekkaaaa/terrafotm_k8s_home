# ==================== PROXMOX API ====================
variable "pm_api_url" {}
variable "pm_api_token_id" {}
variable "pm_api_token_secret" {}
variable "ssh_public_key" {}

# ==================== ОСНОВНЫЕ НАСТРОЙКИ ====================
variable "target_node" {}
variable "template_vmid" {}

# ==================== СЕТЬ И ХРАНИЛИЩА ====================
variable "network_config" {}
variable "bridge" {}
variable "storage_iso" {}
variable "storage_vm" {}

# ==================== VM КОНФИГУРАЦИЯ ====================
variable "cloud_init" {}
variable "static_ip_base" {}
variable "vm_specs" {}
variable "vmid_ranges" {}
variable "cluster_config" {}
variable "template_specs" {}

# SSH доступ к Proxmox
variable "proxmox_ssh_username" {}
variable "proxmox_ssh_password" {}
