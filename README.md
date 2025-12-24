# 🚀 Автоматический деплой Kubernetes кластера на Proxmox

**Полное решение для автоматического развертывания K8s кластера через Terraform и Git CI/CD.**

---

## 📋 Содержание
- [🎯 Основные возможности](#-основные-возможности)
- [🏗️ Архитектура](#️-архитектура)
- [📁 Структура проекта](#-структура-проекта)
- [⚙️ Предварительная настройка](#️-предварительная-настройка)
- [🔐 Настройка секретов CI/CD](#-настройка-секретов-cicd)
- [🛠️ Конфигурационный файл](#️-конфигурационный-файл)
- [🚀 Использование](#-использование)
- [🔧 Устранение неполадок](#-устранение-неполадок)
- [🔄 Workflow процесс](#-workflow-процесс)

---

## 🎯 Основные возможности

✅ **Полная автоматизация** — от шаблона до работающего кластера  
✅ **UEFI загрузка** — современная загрузка всех ВМ  
✅ **Автоподбор IP** — умный поиск свободных адресов  
✅ **Гибкая конфигурация** — настройка количества нод через один файл  
✅ **CI/CD интеграция** — деплой по push в Git  
✅ **Безопасность** — SSH ключи через секреты, API токены  

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

## ⚙️ Предварительная настройка

1. Создание API токена в Proxmox
```# На Proxmox хосте (192.168.0.ххх):
pveum user add terraform --password <ваш_пароль>
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
🔐 Настройка секретов CI/CD

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

