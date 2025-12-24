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

---

## 🏗️ Архитектура

┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Git Server │ │ CI/CD Runner │ │ Proxmox VE │
│ (Gitea) │────│ (Workflow) │────│ (Ваш сервер) │
│ │ │ │ │ │
│ • Репозиторий │ │ • Terraform │ │ • Шаблон 9001 │
│ • Secrets │ │ • Автоподбор IP│ │ • Master 2000 │
│ • Workflows │ │ │ │ • Workers 2100+│
└─────────────────┘ └─────────────────┘ └─────────────────┘

## 📁 Структура проекта

terrafotm_k8s_home/
├── .gitea/
│   └── workflows/
│       └── deploy-master.yml    # CI/CD пайплайн
├── config.auto.tfvars           # Основная конфигурация
├── variables.tf                 # Общие переменные Terraform
├── template/                    # Шаблон ВМ (9001)
│   ├── main.tf                  
│   └── variables.tf
├── master/                      # Master ноды
│   ├── main.tf                 # Terraform для master
│   └── variables.tf
└── worker/                      # Worker ноды
    ├── main.tf                 # Terraform для workers
    └── variables.tf

## ⚙️ Предварительная настройка

1. Создание API токена в Proxmox
```# На Proxmox хосте (192.168.0.ххх):
pveum user add terraform --password <ваш_пароль>
pveum role add terraform -privs "VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.Memory VM.Config.Network VM.Config.Options VM.Config.HWType VM.GuestAgent.Audit VM.GuestAgent.Unrestricted Sys.Audit VM.PowerMgmt Datastore.Allocate Datastore.Audit Datastore.AllocateSpace User.Modify Permissions.Modify SDN.Use SDN.Audit Pool.Allocate Pool.Audit Sys.Console Sys.Modify VM.Migrate"
pveum aclmod / -user terraform -role TerraformProv
pveum token add terraform-token --user terraform-prov@pve --privsep 0```

Запишите:

Token ID: terraform-prov@pve!terraform-token

Token Secret: сгенерированный UUID

2. Создание SSH ключа



