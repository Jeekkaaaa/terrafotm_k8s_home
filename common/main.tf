# common/main.tf - общие настройки
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"   # Единственный правильный источник
      version = "~> 2.9.14"
    }
  }
}

# Переопределяем конфигурацию провайдера для локальной работы
provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

# КЛЮЧЕВОЙ БЛОК: Явно указываем, что провайдер должен быть локальным
# Это предотвращает любые попытки обращения к registry
provider_meta "telmate/proxmox" {
  # Эта директива заставляет Terraform искать провайдера только локально
  module_author = "local"
}
