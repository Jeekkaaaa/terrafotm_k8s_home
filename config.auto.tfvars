# config.auto.tfvars
# Кластер: 1 мастер + 2 воркера
# ВСЕ переменные здесь!

# Основные настройки
target_node = "pve-k8s"
ssh_public_key_path = "/root/.ssh/id_ed25519.pub"
ssh_private_key_path = "/root/.ssh/id_ed25519"

# Кластер
cluster_config = {
  masters_count = 1
  workers_count = 2
  cluster_name  = "home-k8s-cluster"
  domain        = "home.lab"
}

# VM ID диапазоны
vmid_ranges = {
  masters = { start = 2000, end = 2009 }
  workers = { start = 2100, end = 2109 }
}

# Характеристики VM
vm_specs = {
  master = {
    cpu_cores    = 2
    cpu_sockets  = 1
    memory_mb    = 4096
    disk_size_gb = 30
    disk_storage = "local-lvm"
  }
  worker = {
    cpu_cores    = 2
    cpu_sockets  = 1
    memory_mb    = 2048
    disk_size_gb = 20
    disk_storage = "local-lvm"
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

# Автоназначение IP
auto_static_ips = true
static_ip_base  = 110

# Шаблон
template_vmid = 9000
storage = "local-lvm"
bridge = "vmbr0"
