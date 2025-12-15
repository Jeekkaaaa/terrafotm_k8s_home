terraform {
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

locals {
  worker_indices = range(var.cluster_config.workers_count)
}

resource "proxmox_vm_qemu" "k8s_worker" {
  for_each = { for idx in local.worker_indices : idx => idx }

  name        = "k8s-worker-${var.vmid_ranges.workers.start + each.key}"
  target_node = var.target_node
  vmid        = var.vmid_ranges.workers.start + each.key
  description = "K8s Worker ${each.key + 1}"
  
  clone = "ubuntu-template"
  full_clone = true
  
  cores   = var.vm_specs.worker.cpu_cores
  sockets = var.vm_specs.worker.cpu_sockets
  memory  = var.vm_specs.worker.memory_mb
  onboot  = true
  
  disk {
    slot    = 0
    size    = "${var.vm_specs.worker.disk_size_gb}G"
    storage = var.vm_specs.worker.disk_storage
    type    = "scsi"
  }
  
  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_config.bridge
  }
  
  ciuser       = var.cloud_init.user
  sshkeys      = file(var.ssh_public_key_path)
  
  # IP для воркеров начинаются после мастеров
  ipconfig0    = var.auto_static_ips ? "ip=${cidrhost(var.network_config.subnet, var.static_ip_base + var.cluster_config.masters_count + each.key)}/24,gw=${var.network_config.gateway}" : "ip=dhcp"
  
  nameserver   = join(" ", var.network_config.dns_servers)
  searchdomain = join(" ", var.cloud_init.search_domains)
  
  agent  = 1
  scsihw = "virtio-scsi-single"
}

output "workers" {
  value = {
    for idx, vm in proxmox_vm_qemu.k8s_worker : idx => {
      name = vm.name
      vmid = vm.vmid
      ip   = var.auto_static_ips ? cidrhost(var.network_config.subnet, var.static_ip_base + var.cluster_config.masters_count + idx) : "dhcp"
    }
  }
}
