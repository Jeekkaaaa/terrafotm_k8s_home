asdasdasd
## ⚙️ Настройка переменных

### 1. Создайте файл `terraform.tfvars`

**ВНИМАНИЕ:** Этот файл содержит секретные данные! Добавьте его в `.gitignore`

```hcl
# Proxmox настройки
proxmox_config = {
  api_url      = "https://192.168.1.100:8006/api2/json"    # URL вашего Proxmox
  token_id     = "user@pam!terraform_token"                # Ваш токен ID
  token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"    # Ваш секретный токен
  node         = "pve"                                     # Имя ноды Proxmox
  storage      = "local-lvm"                               # Хранилище для дисков
  insecure     = true                                      # Игнорировать SSL ошибки
}

# Сетевые настройки (настройте под свою сеть)
network_config = {
  subnet       = "192.168.1.0/24"                          # Ваша подсеть
  gateway      = "192.168.1.1"                             # Шлюз
  dns_servers  = ["8.8.8.8", "1.1.1.1"]                    # DNS серверы
  bridge       = "vmbr0"                                   # Сетевой мост
  dhcp_start   = 100                                       # Начало DHCP диапазона
  dhcp_end     = 200                                       # Конец DHCP диапазона
}

# VMID диапазоны (уникальные для каждой среды)
vmid_ranges = {
  masters = { start = 4100, end = 4199 }                   # VMID для мастеров
  workers = { start = 4200, end = 4299 }                   # VMID для воркеров
}

# Размер кластера
cluster_config = {
  masters_count = 1                                        # Количество мастер-нод
  workers_count = 2                                        # Количество воркер-нод
  cluster_name  = "k8s-cluster"                            # Имя кластера
  domain        = "lab.local"                              # Домен
}

# Режим IP адресации (рекомендуется true)
auto_static_ips = true                                     # true = автоматические статические IP
static_ip_base  = 110                                      # Базовый IP: 192.168.1.110

# Хардверные настройки (настройте под ваши ресурсы)
vm_specs = {
  master = {
    cpu_cores    = 4                                       # Ядра CPU для мастера
    memory_mb    = 8192                                    # Память для мастера (MB)
    disk_size_gb = 50                                      # Размер диска (GB)
    disk_storage = "local-lvm"                             # Хранилище дисков
    disk_format  = "raw"                                   # Формат диска
  }
  worker = {
    cpu_cores    = 2                                       # Ядра CPU для воркера
    memory_mb    = 4096                                    # Память для воркера (MB)
    disk_size_gb = 30                                      # Размер диска (GB)
    disk_storage = "local-lvm"                             # Хранилище дисков
    disk_format  = "raw"                                   # Формат диска
  }
}

# Cloud-Init настройки
cloud_init = {
  user           = "ubuntu"                                # Пользователь по умолчанию
  ssh_key_path   = "/home/user/.ssh/id_rsa.pub"           # Путь к публичному SSH ключу
  ssh_priv_path  = "/home/user/.ssh/id_rsa"               # Путь к приватному SSH ключу
  search_domains = ["lab.local"]                           # Поисковые домены
}
