[English](README-en.md) | [Русский](README.md) 
# 🚀 Automatic deployment of a Kubernetes cluster on Proxmox.

**A complete solution for automatically deploying a Kubernetes cluster using Terraform and Git CI/CD.**

---

## 📋 Index
- [🎯 Main features](#-main-features)
- [🏗️ Architecture](#-architecture)
- [📁 Project structure](#-project-structure)
- [⚙️ Preconfiguration](#-preconfiguration)
- [🔐 Configuring secrets CI/CD](#-configuring-secrets-ci/cd)
- [🛠️ Configuration file](#-configuration-file)
- [🚀 Usage](#-usage)
- [🔧 Troubleshooting](#-troubleshooting)
- [🔄 Workflow](#-workflow)
- [📊 Examples](#-examples)
- [🔐 Security](#-security)
- [📞 Support](#-support)
- [🎯 Quick start](#-quick-start)

---

## 🎯 Main features

✅ **Full automation** — from template to working cluster    
✅ **UEFI** — modern loading of all virtual machines    
✅ **Auto selection IP** — smart search for available addresses    
✅ **Flexible configurationя** — setting the number of nodes via one file    
✅ **CI/CD integration** — deployment via push in Git    
✅ **Security** — SSH keys via secrets, API tokens    

---

## 🏗️ Architecture

```text
┌─────────────────┐    ┌────────────────────┐    ┌─────────────────┐
│   Git Server    │    │   CI/CD Runner     │    │   Proxmox VE    │
│   (Gitea)       │────│   (Workflow)       │────│ (192.168.0.223) │
│                 │    │                    │    │                 │
│  • Repository   │    │ • Terraform        │    │  • Template 9001│
│  • Secrets      │    │ • Auto selection IP│    │  • Master 2000+ │
│  • Workflows    │    │                    │    │  • Workers 2100+│
└─────────────────┘    └────────────────────┘    └─────────────────┘
```

---

## 📁 Project structure
```text
terrafotm_k8s_home/
├── .gitea/
│   └── workflows/
│       └── deploy-master.yml    # CI/CD pipeline
├── config.auto.tfvars           # Main configuration
├── variables.tf                 # Global variables Terraform
├── template/                    # Template VM (9001)
│   ├── main.tf
│   └── variables.tf
├── master/                      # Master-nodes
│   ├── main.tf
│   └── variables.tf
└── worker/                      # Worker-nodes
    ├── main.tf
    └── variables.tf
```
---

## ⚙️ Preconfiguration

1. Creating an API token in Proxmox
Proxmox host (192.168.0.ххх):
```pveum user add terraform --password <very_strong_password>
pveum role add terraform -privs "VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.Memory VM.Config.Network VM.Config.Options VM.Config.HWType VM.GuestAgent.Audit VM.GuestAgent.Unrestricted Sys.Audit VM.PowerMgmt Datastore.Allocate Datastore.Audit Datastore.AllocateSpace User.Modify Permissions.Modify SDN.Use SDN.Audit Pool.Allocate Pool.Audit Sys.Console Sys.Modify VM.Migrate"
pveum aclmod / -user terraform -role TerraformProv
pveum token add terraform-token --user terraform-prov@pve --privsep 0
```

Make a note:

- Token ID: terraform-prov@pve!terraform-token

- Token Secret: generated UUID

2. Creating an SSH key

```bash
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
cat /root/.ssh/id_ed25519.pub
```
---

## 🔐 Configuring secrets CI/CD

Add the following 6 secrets to the CI/CD system (Gitea / GitHub / GitLab):

```text
Secret | Description | Example
PM_API_URL	URL Proxmox API	https://192.168.0.223:8006/api2/json

PM_API_TOKEN_ID	ID API token	terraform-prov@pve!terraform-token

PM_API_TOKEN_SECRET	Secret API token	xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

PROXMOX_SSH_USERNAME	SSH user	root

PROXMOX_SSH_PASSWORD	SSH password	super_strong_password

PROXMOX_SSH_PUBKEY	Public SSH-key	ssh-ed25519 AAAAC3...


⚠️ All 6 secrets are mandatory
```
---

## 🛠️ Configuration file

config.auto.tfvars — Central Management File

```hcl
# General
target_node = "proxmox-node"        # Name of node Proxmox

# Template
template_vmid = 9000                # VMID template

# Claster (Edit settings here!)
cluster_config = {
  masters_count = 1                 # How many master nodes (0-9)
  workers_count = 2                 # How many worker nodes (0-9)
  cluster_name  = "example-k8s-cluster"
  domain        = "example.local"
}

# VM ID (range)
vmid_ranges = {
  masters = { start = 1000, end = 1009 }  # Master nodes
  workers = { start = 1100, end = 1109 }  # Worker nodes
}

# Settings VM
vm_specs = {
  master = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 4096    # 4GB RAM
    disk_size_gb       = 40      # Disk size
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
  worker = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 2048    # 2GB RAM
    disk_size_gb       = 30      # Disk size
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
}

# Network (Edit settings by your network configuration!)
network_config = {
  subnet       = "10.0.0.0/24"       # claster subnet 
  gateway      = "10.0.0.1"          # Gateway
  dns_servers  = ["1.1.1.1", "8.8.8.8"]
  bridge       = "vmbr0"             # Proxmox gateway
}

# Cloud-init
cloud_init = {
  user           = "clouduser"       # Default user
  search_domains = ["example.local"]
}

# Auto selection IP (This is filled in automatically)
static_ip_base = 100
```
---

## 🚀 Usage

Automatic deployment (recommended)

```bash
# Any push to the main branch triggers a deployment.
git add .
git commit -m "Cluster update"
git push origin main
```
## 🔧 Troubleshooting

❌ Error: got: = during deployment
Reason: Empty secrets PM_API_TOKEN_ID or PM_API_TOKEN_SECRET
Solution: Check all 6 secrets in the CI/CD system.

❌ Error: SSH WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED
Reason: The virtual machine was recreated, and the SSH host key has changed.
Solution:
```bash
ssh-keygen -f '/root/.ssh/known_hosts' -R '<IP_address>'
ssh -o StrictHostKeyChecking=no ubuntu@<IP_address>
```
⚠️ Warning: Value for undeclared variable
Reason: Extra variables inconfig.auto.tfvars
Solution: Delete the rows bridge = ... and storage = ...

❌ Master is created when masters_count = 0
Reason: Old version of master/main.tf
Solution: Update the file to support count = var.cluster_config.masters_count

---

## 🔄 Workflow

Every push to main:

1. ✅ Checkout code — repository loading

2. 🔍 Read network config — check subnet

3. 🎯 Auto-find Free IP Range — searching for available IP addresses

4. 📝 Update config — update static_ip_base

5. 🏗️ Create Template — creating/updating template 9001

6. 🚀 Deploy Cluster — creating master and worker nodes

---

## 📊 Examples

Workers only (No master)
```hcl
cluster_config = {
  masters_count = 0
  workers_count = 3
}

Result: 3 worker nodes from IP .111, .112, .113
```
Classic cluster
```hcl
cluster_config = {
  masters_count = 1
  workers_count = 2
}

Result: 1 master (.111) + 2 workers (.112, .113)
```
High Availability
```hcl
cluster_config = {
  masters_count = 3
  workers_count = 3
}

Result: 3 masters (.111-.113) + 3 workers (.114-.116)
```
---

## 🔐 Security

1. API tokens — separate user with minimal privileges

2. SSH keys — private key on Proxmox only

3. Secrets — never be stored in Git, only in the CI/CD system

4. Network — firewall configuration is recommended.

---

## 📞 Support

1. ✅ All 6 secrets have been set and are not empty

2. ✅ config.auto.tfvars is configured for your infrastructure

3. ✅ Proxmox API token has the necessary permissions

4. ✅ Proxmox is accessible from the CI/CD runner network

Logs:

- Workflow logs in the Git system

- Terraform logs in the workflow output

- Proxmox logs: qm config <vmid> and journalctl

---

## 🎯 Quick start

1. Configure the Proxmox API token

2. Add 6 secrets to the Git system

3. Edit config.auto.tfvars (especially the subnet and gateway)

4. Push the changes to the main branch

5. Connect using: ssh ubuntu@<received_IP>

---

Version: 2.0.0
Last edit: December 2025
Сreator: Jeekkaaaa
Translate Ru-En: Atomizeee
