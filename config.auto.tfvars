# Proxmox API (через secrets в workflow)
pm_api_url          = ""
pm_api_token_id     = ""
pm_api_token_secret = ""

target_node = "pve-k8s"
ssh_public_key_path = "/root/.ssh/id_ed25519.pub"
ssh_private_key_path = "/root/.ssh/id_ed25519"

cluster_config = {
  masters_count = 1
  workers_count = 2
  cluster_name  = "home-k8s-cluster"
  domain        = "home.lab"
}

vmid_ranges = {
  masters = { start = 2000, end = 2009 }
  workers = { start = 2100, end = 2109 }
}

vm_specs = {
  master = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 4096
    disk_size_gb       = 30
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
  worker = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 2048
    disk_size_gb       = 20
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
}

template_specs = {
  cpu_cores     = 2
  cpu_sockets   = 1
  memory_mb     = 2048
  disk_size_gb  = 12
  disk_iothread = true
}

network_config = {
  subnet       = "192.168.0.0/24"
  gateway      = "192.168.0.1"
  dns_servers  = ["8.8.8.8", "1.1.1.1"]
  bridge       = "vmbr0"
}

cloud_init = {
  user           = "ubuntu"
  search_domains = ["home.lab"]
}

auto_static_ips = true
static_ip_base  = 110
template_vmid   = 9000
storage         = "local-lvm"
bridge          = "vmbr0"
