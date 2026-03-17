# Корневой модуль для оркестрации развертывания

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

# Модуль создания шаблона
module "template" {
  source = "./template"

  # Proxmox API
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  
  # Основные настройки
  target_node    = var.target_node
  ssh_public_key = var.ssh_public_key
  template_vmid  = var.template_vmid
  
  # Сеть и хранилища
  bridge      = var.bridge
  storage_iso = var.storage_iso
  storage_vm  = var.storage_vm
  
  # Спецификации
  template_specs = var.template_specs
}

# Модуль мастер-нод
module "master" {
  source = "./master"

  # Proxmox API
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  
  # Основные настройки
  target_node    = var.target_node
  ssh_public_key = var.ssh_public_key
  template_vmid  = var.template_vmid
  
  # Сеть и хранилища
  bridge      = var.bridge
  storage_iso = var.storage_iso
  storage_vm  = var.storage_vm
  
  # Конфигурация ВМ
  cluster_config  = var.cluster_config
  vmid_ranges     = var.vmid_ranges
  vm_specs        = var.vm_specs
  network_config  = var.network_config
  cloud_init      = var.cloud_init
  template_specs  = var.template_specs
  
  # IP адресация
  auto_static_ips = var.auto_static_ips
  static_ip_base  = var.static_ip_base
}

# Модуль воркер-нод
module "worker" {
  source = "./worker"

  # Proxmox API
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  
  # Основные настройки
  target_node    = var.target_node
  ssh_public_key = var.ssh_public_key
  template_vmid  = var.template_vmid
  
  # Сеть и хранилища
  bridge      = var.bridge
  storage_iso = var.storage_iso
  storage_vm  = var.storage_vm
  
  # Конфигурация ВМ
  cluster_config  = var.cluster_config
  vmid_ranges     = var.vmid_ranges
  vm_specs        = var.vm_specs
  network_config  = var.network_config
  cloud_init      = var.cloud_init
  template_specs  = var.template_specs
  
  # IP адресация
  auto_static_ips = var.auto_static_ips
  static_ip_base  = var.static_ip_base
}

output "template_info" {
  value = module.template.template_id
}

output "masters_info" {
  value = module.master.masters
}

output "workers_info" {
  value = module.worker.workers
}
