# 🚀 Автоматический деплой Kubernetes кластера на Proxmox

**Полное решение для автоматического развертывания K8s кластера через Terraform и Git CI/CD.**

---

## 📋 Содержание
- [🎯 Основные возможности](#-основные-возможности)
- [🏗️ Архитектура](#-архитектура)
- [📁 Структура проекта](#-структура-проекта)
- [⚙️ Предварительная настройка](#-предварительная-настройка)
- [🔐 Настройка секретов CI/CD](#-настройка-секретов-cicd)
- [🛠️ Конфигурационный файл](#-конфигурационный-файл)
- [🚀 Использование](#-использование)
- [🔧 Устранение неполадок](#-устранение-неполадок)
- [🔄 Workflow процесс](#-workflow-процесс)
- [📊 Примеры конфигураций](#-примеры-конфигураций)
- [🔐 Безопасность](#-безопасность)
- [📞 Поддержка](#-поддержка)
- [🎯 Быстрый старт](#-быстрый-старт)

---

## 🎯 Основные возможности

✅ **Полная автоматизация** — от шаблона до работающего кластера  
✅ **UEFI загрузка** — современная загрузка всех ВМ  
✅ **Автоподбор IP** — умный поиск свободных адресов  
✅ **Гибкая конфигурация** — настройка количества нод через один файл  
✅ **CI/CD интеграция** — деплой по push в Git  
✅ **Безопасность** — SSH ключи через секреты, API токены  

---

## 🏗️ Архитектура

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Git Server    │    │   CI/CD Runner  │    │   Proxmox VE    │
│   (Gitea)       │────│   (Workflow)    │────│ (192.168.0.223) │
│                 │    │                 │    │                 │
│  • Репозиторий  │    │  • Terraform    │    │  • Template 9001│
│  • Secrets      │    │  • Автоподбор IP│    │  • Master 2000+ │
│  • Workflows    │    │                 │    │  • Workers 2100+│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## 📁 Структура проекта
```text
terrafotm_k8s_home/
├── .gitea/
│   └── workflows/
│       └── deploy-master.yml    # CI/CD пайплайн
├── config.auto.tfvars           # Основная конфигурация
├── variables.tf                 # Общие переменные Terraform
├── template/                    # Шаблон ВМ (9001)
│   ├── main.tf
│   └── variables.tf
├── master/                      # Master-ноды
│   ├── main.tf
│   └── variables.tf
└── worker/                      # Worker-ноды
    ├── main.tf
    └── variables.tf
```
---

## ⚙️ Предварительная настройка

1. Создание API токена в Proxmox
На Proxmox хосте (192.168.0.ххх):
```pveum user add terraform --password <ваш_пароль>
pveum role add terraform -privs "VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.Memory VM.Config.Network VM.Config.Options VM.Config.HWType VM.GuestAgent.Audit VM.GuestAgent.Unrestricted Sys.Audit VM.PowerMgmt Datastore.Allocate Datastore.Audit Datastore.AllocateSpace User.Modify Permissions.Modify SDN.Use SDN.Audit Pool.Allocate Pool.Audit Sys.Console Sys.Modify VM.Migrate"
pveum aclmod / -user terraform -role TerraformProv
pveum token add terraform-token --user terraform-prov@pve --privsep 0
```

Запишите:

- Token ID: terraform-prov@pve!terraform-token

- Token Secret: сгенерированный UUID

2. Создание SSH ключа

```bash
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
cat /root/.ssh/id_ed25519.pub
```
---

## 🔐 Настройка секретов CI/CD

Добавьте следующие 6 секретов в CI/CD систему (Gitea / GitHub / GitLab):

```text
Секрет	Описание	Пример
PM_API_URL	URL Proxmox API	https://192.168.0.223:8006/api2/json

PM_API_TOKEN_ID	ID API токена	terraform-prov@pve!terraform-token

PM_API_TOKEN_SECRET	Secret API токена	xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

PROXMOX_SSH_USERNAME	SSH пользователь	root

PROXMOX_SSH_PASSWORD	SSH пароль	ваш_пароль

PROXMOX_SSH_PUBKEY	Публичный SSH-ключ	ssh-ed25519 AAAAC3...


⚠️ Все 6 секретов обязательны
```
---

## 🛠️ Конфигурационный файл

config.auto.tfvars — единый файл управления

```hcl
# Основные
target_node = "proxmox-node"        # Имя ноды Proxmox

# Шаблон
template_vmid = 9000                # VMID шаблона

# Кластер (НАСТРАИВАЙТЕ ЗДЕСЬ!)
cluster_config = {
  masters_count = 1                 # Сколько master нод (0-9)
  workers_count = 2                 # Сколько worker нод (0-9)
  cluster_name  = "example-k8s-cluster"
  domain        = "example.local"
}

# VM ID (диапазоны)
vmid_ranges = {
  masters = { start = 1000, end = 1009 }  # Master ноды
  workers = { start = 1100, end = 1109 }  # Worker ноды
}

# Характеристики ВМ
vm_specs = {
  master = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 4096    # 4GB RAM
    disk_size_gb       = 40      # Размер диска
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
  worker = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 2048    # 2GB RAM
    disk_size_gb       = 30      # Размер диска
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
}

# Сеть (НАСТРОЙТЕ ПОД СВОЮ СЕТЬ!)
network_config = {
  subnet       = "10.0.0.0/24"       # Подсеть кластера
  gateway      = "10.0.0.1"          # Шлюз
  dns_servers  = ["1.1.1.1", "8.8.8.8"]
  bridge       = "vmbr0"             # Сетевой мост Proxmox
}

# Cloud-init
cloud_init = {
  user           = "clouduser"       # Пользователь по умолчанию
  search_domains = ["example.local"]
}

# Автоподбор IP (заполняется автоматически)
static_ip_base = 100
```
---

## 🚀 Использование

Автоматический деплой (рекомендуется)

```bash
# Любой push в main ветку запускает деплой
git add .
git commit -m "Обновление кластера"
git push origin main
```
## 🔧 Устранение неполадок

❌ Ошибка: got: = при деплое
Причина: Пустые секреты PM_API_TOKEN_ID или PM_API_TOKEN_SECRET
Решение: Проверьте все 6 секретов в CI/CD системе

❌ Ошибка: SSH WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED
Причина: ВМ пересоздана, изменился SSH host key
Решение:
```bash
ssh-keygen -f '/root/.ssh/known_hosts' -R '<IP_адрес>'
ssh -o StrictHostKeyChecking=no ubuntu@<IP_адрес>
```
⚠️ Предупреждение: Value for undeclared variable
Причина: Лишние переменные в config.auto.tfvars
Решение: Удалите строки bridge = ... и storage = ...

❌ Master создается при masters_count = 0
Причина: Старая версия master/main.tf
Решение: Обновите файл с поддержкой count = var.cluster_config.masters_count

---

## 🔄 Workflow процесс 

При каждом push в main ветку:

1. ✅ Checkout code — загрузка репозитория

2. 🔍 Read network config — чтение подсети

3. 🎯 Auto-find Free IP Range — поиск свободных IP

4. 📝 Update config — обновление static_ip_base

5. 🏗️ Create Template — создание/обновление шаблона 9001

6. 🚀 Deploy Cluster — создание master и worker нод

---

## 📊 Примеры конфигураций

Только workers (без master)
```hcl
cluster_config = {
  masters_count = 0
  workers_count = 3
}

Результат: 3 worker ноды с IP .111, .112, .113
```
Классический кластер
```hcl
cluster_config = {
  masters_count = 1
  workers_count = 2
}

Результат: 1 master (.111) + 2 workers (.112, .113)
```
High Availability
```hcl
cluster_config = {
  masters_count = 3
  workers_count = 3
}

Результат: 3 masters (.111-.113) + 3 workers (.114-.116)
```
---

## 🔐 Безопасность

1. API токены — отдельный пользователь с минимальными правами

2. SSH ключи — приватный ключ только на Proxmox

3. Секреты — никогда не в Git, только в CI/CD системе

4. Сеть — рекомендуется настройка firewall

---

## 📞 Поддержка

1. ✅ Все 6 секретов установлены и не пустые

2. ✅ config.auto.tfvars настроен под вашу инфраструктуру

3. ✅ API токен Proxmox имеет необходимые права

4. ✅ Proxmox доступен из сети CI/CD runner

Логи:

- Workflow логи в Git системе

- Terraform логи в workflow output

- Proxmox логи: qm config <vmid> и journalctl

---

## 🎯 Быстрый старт

1. Настройте Proxmox API токен

2. Добавьте 6 секретов в Git систему

3. Отредактируйте config.auto.tfvars (особенно подсеть и шлюз)

4. Сделайте push в main ветку

5. Подключайтесь: ssh ubuntu@<полученный_IP>

---

Версия: 2.0.0
Последнее обновление: Декабрь 2025
Автор: Jeekkaaaa
