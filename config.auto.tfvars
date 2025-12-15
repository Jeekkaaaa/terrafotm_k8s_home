# config.auto.tfvars
# ВСЁ, что вы меняете для деплоя, указывается здесь.
# Этот файл можно и нужно коммитить в репозиторий.

# ========== 1. КЛЮЧЕВОЙ ПАРАМЕТР: СКОЛЬКО МАШИН ==========
# Пока что этот параметр НЕ БУДЕТ РАБОТАТЬ, пока не изменим main.tf.
# Но мы его сразу прописываем.
cluster_config = {
  masters_count = 3          # Желаемое количество мастер-нод
  workers_count = 2
  cluster_name  = "home-k8s"
  domain        = "home.lab"
}

# ========== 2. ХРАНИЛИЩЕ ДИСКОВ ==========
# ЭТО СРАБОТАЕТ СРАЗУ! Поменяете "big_oleg" — диски создадутся там.
vm_specs = {
  master = {
    cpu_cores    = 4
    cpu_sockets  = 1
    memory_mb    = 8192
    disk_size_gb = 50
    disk_storage = "local-lvm"  # Ваше хранилище для мастер-нод
    disk_format  = "raw"
  }
  worker = {
    cpu_cores    = 2
    cpu_sockets  = 1
    memory_mb    = 4096
    disk_size_gb = 30
    disk_storage = "local-lvm"  # Ваше хранилище для воркер-нод
    disk_format  = "raw"
  }
}

# ========== 3. СЕТЕВЫЕ НАСТРОЙКИ ==========
network_config = {
  subnet       = "192.168.0.0/24"
  gateway      = "192.168.0.1"
  dns_servers  = ["8.8.8.8"]
  bridge       = "vmbr0"
  dhcp_start   = 100
  dhcp_end     = 150
}

# ========== 4. ДРУГИЕ НАСТРОЙКИ ==========
# Включаем автоматические статические IP
auto_static_ips = true
static_ip_base  = 110

# Целевая нода Proxmox
target_node = "pve-k8s"

# Настройки Cloud-Init
cloud_init = {
  user           = "ubuntu"
  search_domains = ["home.lab"]
}
