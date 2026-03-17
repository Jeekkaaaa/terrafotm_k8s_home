terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.56.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
  insecure  = true
  
  ssh {
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
  }
}

locals {
  subnet_parts = split(".", var.network_config.subnet)
  network_prefix = "${local.subnet_parts[0]}.${local.subnet_parts[1]}.${local.subnet_parts[2]}"
  worker_ips = [
    for i in range(var.cluster_config.workers_count) : 
    "${local.network_prefix}.${var.static_ip_base + var.cluster_config.masters_count + i}"
  ]
}

resource "proxmox_virtual_environment_vm" "k8s_worker" {
  count = var.cluster_config.workers_count

  name      = "k8s-worker-${var.vmid_ranges.workers.start + count.index}"
  node_name = var.target_node
  vm_id     = var.vmid_ranges.workers.start + count.index
  started   = true

  clone {
    vm_id = var.template_vmid
    node_name = var.target_node
    full = true
  }

  cpu {
    cores   = var.vm_specs.worker.cpu_cores
    sockets = var.vm_specs.worker.cpu_sockets
  }

  memory {
    dedicated = var.vm_specs.worker.memory_mb
  }

  disk {
    datastore_id = var.vm_specs.worker.disk_storage
    size         = var.vm_specs.worker.disk_size_gb
    interface    = "scsi0"
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.vm_specs.worker.cloudinit_storage

    user_account {
      username = var.cloud_init.user
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = var.network_config.dns_servers
      domain  = var.cloud_init.search_domains[0]
    }

    ip_config {
      ipv4 {
        address = "${local.worker_ips[count.index]}/24"
        gateway = var.network_config.gateway
      }
    }
  }

  network_device {
    bridge = var.network_config.bridge
    model  = "virtio"
  }

  agent {
    enabled = false
  }

  boot_order = ["scsi0"]
  scsi_hardware = "virtio-scsi-pci"
  on_boot = true

  timeout_create = 180

  lifecycle {
    ignore_changes = [
      disk[0].size,
      network_device,
    ]
  }
}

output "worker_ips" {
  value = local.worker_ips
}
