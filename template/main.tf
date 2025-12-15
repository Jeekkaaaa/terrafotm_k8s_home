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

# Создаем шаблонную VM
resource "proxmox_vm_qemu" "ubuntu_template" {
  name        = "ubuntu-template"
  target_node = var.target_node
  vmid        = var.template_vmid
  desc        = "Ubuntu 22.04 Cloud-Init Template (Auto-generated)"
  
  cores   = 2
  sockets = 1
  memory  = 2048
  
  # Диск
  disk {
    slot     = 0
    storage  = var.storage
    type     = "scsi"
    size     = "12G"
  }
  
  # Cloud-init диск
  disk {
    slot    = 2
    storage = var.storage
    type    = "cloudinit"
  }
  
  # Сеть
  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }
  
  # Cloud-init
  ciuser  = "ubuntu"
  sshkeys = var.ssh_public_key
  
  # Важно: ISO не указываем, создаем пустую VM
  onboot    = false
  agent     = 1
  os_type   = "cloud-init"
  scsihw    = "virtio-scsi-single"
  bootdisk  = "scsi0"
  
  lifecycle {
    ignore_changes = [network]
  }
  
  # После создания превращаем в шаблон
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for VM to be created..."
      sleep 10
      echo "Converting VM ${self.vmid} to template..."
      qm set ${self.vmid} --template 1
    EOT
  }
}

