# Основные
target_node = "pve-k8s"
ssh_public_key = ""

# Шаблон
template_vmid = 9000

# Кластер
cluster_config = {
  masters_count = 1
  workers_count = 2
  cluster_name  = "home-k8s-cluster"
  domain        = "home.lab"
}

# VM ID
vmid_ranges = {
  masters = { start = 2000, end = 2009 }
  workers = { start = 2100, end = 2109 }
}

# Спецификации VM
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

# Сеть
network_config = {
  subnet       = "192.168.0.0/24"
  gateway      = "192.168.0.1"
  dns_servers  = ["8.8.8.8", "1.1.1.1"]
  bridge       = "vmbr0"
}

# Cloud-init
cloud_init = {
  user           = "ubuntu"
  search_domains = ["home.lab"]
}

# Остальное
storage = "local-lvm"
bridge = "vmbr0"

# Автоподбор IP (заполнится workflow)
static_ip_base = 100

# Характеристики шаблона
template_specs = {
  cpu_cores     = 2
  cpu_sockets   = 1
  memory_mb     = 2048
  disk_size_gb  = 12
  disk_iothread = true
}

# Хранилища
storage_iso = "local"  # Для образов ISO (Directory storage)
storage_vm  = "local-lvm"  # Для дисков ВМ (LVM storage)
