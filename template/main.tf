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

resource "proxmox_vm_qemu" "ubuntu_template" {
  name        = "ubuntu-template"
  target_node = var.target_node
  vmid        = var.template_vmid
  desc        = "Ubuntu 22.04 Cloud-Init Template (Auto-generated)"
  
  cpu {
    cores   = var.template_specs.cpu_cores
    sockets = var.template_specs.cpu_sockets
  }
  
  memory  = var.template_specs.memory_mb
  start_at_node_boot = false
  
  disk {
    slot     = "scsi0"
    type     = "disk"
    storage  = var.storage
    size     = "${var.template_specs.disk_size_gb}G"
    iothread = var.template_specs.disk_iothread
  }
  
  disk {
    slot    = "scsi2"
    type    = "cloudinit"
    storage = var.storage
  }
  
  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }
  
  ciuser  = "ubuntu"
  sshkeys = var.ssh_public_key
  
  agent     = 1
  os_type   = "cloud-init"
  scsihw    = "virtio-scsi-single"
  bootdisk  = "scsi0"
  
  lifecycle {
    ignore_changes = [network]
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for VM ${self.vmid} to be created..."
      sleep 30
      echo "Converting VM ${self.vmid} to template..."
      qm set ${self.vmid} --template 1
      echo "Template ${self.vmid} ready!"
    EOT
  }
}
