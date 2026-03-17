# ==================== ОСНОВНЫЕ НАСТРОЙКИ ====================
target_node = "pve-k8s"
template_vmid = 9001

# ==================== КЛАСТЕР КУБЕРНЕТЕС ====================
cluster_config = {
  masters_count = 1
  workers_count = 1
  cluster_name  = "home-k8s-cluster"
  domain        = "home.lab"
  environment   = "production"
}

# ==================== VM ID ДИАПАЗОНЫ ====================
vmid_ranges = {
  masters = { start = 2000, end = 2009 }
  workers = { start = 2100, end = 2109 }
}

# ==================== СПЕЦИФИКАЦИИ VM ====================
vm_specs = {
  master = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 5632
    disk_size_gb       = 20
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
  worker = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 5632
    disk_size_gb       = 20
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
}

# ==================== СЕТЕВЫЕ НАСТРОЙКИ ====================
network_config = {
  subnet       = "192.168.10.0/24"
  gateway      = "192.168.10.1"
  dns_servers  = ["8.8.8.8", "1.1.1.1"]
  bridge       = "vmbr0"
}

# ==================== CLOUD-INIT ====================
cloud_init = {
  user           = "ubuntu"
  search_domains = ["home.lab"]
}

# ==================== KUBERNETES КОНФИГУРАЦИЯ ====================
kubernetes_config = {
  version           = "1.30"
  pod_network_cidr  = "10.244.0.0/16"
  service_cidr      = "10.96.0.0/12"
  cri_socket        = "unix:///var/run/containerd/containerd.sock"

  # HA конфигурация (для multi-master)
  ha_config = {
    enabled            = false
    load_balancer_ip   = ""
    keepalived_vrid    = 51
  }

  # Компоненты
  components = {
    coredns_version   = "1.11.1"
    etcd_version      = "3.5.13"
  }
}

# ==================== СЕТЕВОЙ ПЛАГИН ====================
cni_config = {
  plugin         = "calico"
  version        = "v3.28.0"
  # ФИКС: убрать ${var.} - это не интерполируется в YAML
  manifest_url   = "https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml"
  ipip_mode      = "Always"
  nat_outgoing   = true
}

# ==================== ДОПОЛНИТЕЛЬНЫЕ КОМПОНЕНТЫ ====================
addons_config = {
  # Ingress Controller
  ingress = {
    enabled    = true
    controller = "nginx"
    version    = "v1.10.0"
    helm_chart = "ingress-nginx/ingress-nginx"
  }

  # Load Balancer
  metallb = {
    enabled    = true
    version    = "v0.14.4"
    ip_range   = "192.168.0.200-192.168.0.220"
  }

  # Хранилище
  storage = {
    enabled      = true
    provisioner  = "local-path"
    version      = "v0.0.26"
  }

  # Мониторинг
  monitoring = {
    enabled       = false
    prometheus    = "v2.52.0"
    grafana       = "10.4.0"
  }

  # Helm
  helm = {
    enabled = true
    version = "v3.15.2"
  }
}

# ==================== РЕПОЗИТОРИИ ====================
repositories = {
  # Ansible репозиторий - ФИКС: указать ваш реальный URL
  ansible = {
    url      = "https://gitea.jeekkaaaa.com/jeekkaaaa/ansible_k8s_home.git"
    branch   = "main"
    path     = "ansible-repo"
  }

  # Kubernetes репозитории
  kubernetes = {
    packages     = "https://pkgs.k8s.io/core:/stable:/v1.30/deb/"
    helm_script  = "https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
  }

  # Container registry
  registry = {
    containerd = "https://download.docker.com/linux/ubuntu"
  }
}

# ==================== GITEA SECRETS ====================
secrets_config = {
  gitea_secrets = {
    pm_api_url            = "PM_API_URL"
    pm_api_token_id       = "PM_API_TOKEN_ID"
    pm_api_token_secret   = "PM_API_TOKEN_SECRET"
    proxmox_ssh_username  = "PROXMOX_SSH_USERNAME"
    proxmox_ssh_password  = "PROXMOX_SSH_PASSWORD"
    proxmox_ssh_pubkey    = "PROXMOX_SSH_PUBKEY"
    proxmox_ssh_private   = "PROXMOX_SSH_PRIVATE_KEY"
    gitea_token           = "GITE_TOKEN"
  }
}

# ==================== CI/CD WORKFLOW ====================
workflow_config = {
  # Поиск IP
  ip_search = {
    range_start = 100
    range_end   = 240
    buffer_ips  = 1
  }

  # Таймауты (секунды)
  timeouts = {
    template_create  = 300
    vm_boot          = 180
    ssh_ready        = 120
    cluster_init     = 600
    cni_install      = 300
    addons_install   = 600
  }

  # Повторные попытки
  retries = {
    ssh_connection  = 5
    api_ready       = 10
    node_join       = 3
  }
}

# ==================== ХРАНИЛИЩА PROXMOX ====================
storage = {
  iso   = "local"
  vm    = "local-lvm"
  cloud = "local-lvm"
}

# ==================== ШАБЛОН VM ====================
template_specs = {
  cpu_cores     = 2
  cpu_sockets   = 1
  memory_mb     = 2048
  disk_size_gb  = 12
  disk_iothread = true
}

# ==================== АВТОПОДБОР IP ====================
auto_static_ips = true
static_ip_base  = 100

# ==================== ANSIBLE КОНФИГУРАЦИЯ ====================
ansible_config = {
  user              = "ubuntu"
  python_interpreter = "/usr/bin/python3"
  become_method     = "sudo"
  ssh_args          = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30"

  # Playbook names
  playbooks = {
    base        = "01-base.yml"
    containerd  = "02-containerd.yml"
    kubernetes  = "03-kubernetes.yml"
    init        = "04-cluster-init.yml"
    cni         = "05-cni.yml"
    worker      = "06-worker-join.yml"
    addons      = "07-addons.yml"
    ingress     = "08-ingress.yml"
    storage     = "09-storage.yml"
    metallb     = "10-metallb.yml"
    verify      = "12-verify.yml"
  }

  # Таймауты
  timeouts = {
    ssh_connection  = 30
    task_execution  = 600
    reboot_wait     = 120
  }
}

# ==================== ОБЯЗАТЕЛЬНЫЕ ПЕРЕМЕННЫЕ ====================
# Эти переменные должны быть НА ВЕРХНЕМ УРОВНЕ для работы модулей
bridge = "vmbr0"
storage_iso = "local"
storage_vm = "local-lvm"

# ==================== ANSIBLE РЕПОЗИТОРИЙ ====================
ansible_repo_url = "https://gitea.jeekkaaaa.com/jeekkaaaa/ansible_k8s_home.git"
