terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.56.1"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
  }
}
