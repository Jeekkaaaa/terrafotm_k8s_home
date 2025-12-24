# Общие переменные

variable "pm_api_url" {}
variable "pm_api_token_id" {}
variable "pm_api_token_secret" {}
variable "proxmox_ssh_username" {}
variable "proxmox_ssh_password" {}

variable "target_node" {}
variable "template_vmid" {}  # ТЕПЕРЬ ДОСТУПНО!
variable "ssh_public_key" {}

variable "network_config" {}
variable "cloud_init" {}
variable "static_ip_base" {}

variable "vm_specs" {}
variable "vmid_ranges" {}
