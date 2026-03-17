#!/usr/bin/env python3
"""
Динамический инвентарь для Ansible из Terraform output
Использует terraform output -json для получения IP адресов
"""

import json
import subprocess
import sys
import os
from typing import Dict, Any

class TerraformInventory:
    def __init__(self, terraform_dir: str = "."):
        self.terraform_dir = terraform_dir
        self.inventory = {
            "_meta": {"hostvars": {}},
            "all": {"vars": self.get_common_vars()}
        }
    
    def get_common_vars(self) -> Dict[str, Any]:
        """Общие переменные для всех хостов"""
        return {
            "ansible_user": "ubuntu",
            "ansible_ssh_private_key_file": "/tmp/ssh_key",
            "ansible_ssh_common_args": "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
            "ansible_python_interpreter": "/usr/bin/python3",
            "ansible_become": "yes"
        }
    
    def run_terraform_output(self, module: str = ".") -> Dict[str, Any]:
        """Запускает terraform output в указанном модуле"""
        try:
            original_dir = os.getcwd()
            module_path = os.path.join(self.terraform_dir, module)
            
            if os.path.exists(module_path):
                os.chdir(module_path)
            
            result = subprocess.run(
                ["terraform", "output", "-json"],
                capture_output=True,
                text=True,
                check=True
            )
            
            os.chdir(original_dir)
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            print(f"Error running terraform output in {module}: {e}", file=sys.stderr)
            return {}
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            return {}
    
    def generate_inventory(self) -> Dict[str, Any]:
        """Генерирует полный инвентарь"""
        
        # Получаем данные из master модуля
        master_data = self.run_terraform_output("master")
        worker_data = self.run_terraform_output("worker")
        
        # Обрабатываем master ноды
        if "master_ips" in master_data:
            master_ips = master_data["master_ips"]["value"]
            
            self.inventory["k8s_masters"] = {
                "hosts": {},
                "vars": {
                    "k8s_role": "master",
                    "k8s_node_type": "control-plane"
                }
            }
            
            for idx, ip in enumerate(master_ips, 1):
                hostname = f"master{idx}"
                self.inventory["k8s_masters"]["hosts"][hostname] = {
                    "ansible_host": ip
                }
                self.inventory["_meta"]["hostvars"][hostname] = {
                    "ansible_host": ip,
                    "node_name": f"k8s-master-{1999 + idx}",  # 2000, 2001 и т.д.
                    "node_index": idx
                }
        
        # Обрабатываем worker ноды
        if "worker_ips" in worker_data:
            worker_ips = worker_data["worker_ips"]["value"]
            
            self.inventory["k8s_workers"] = {
                "hosts": {},
                "vars": {
                    "k8s_role": "worker",
                    "k8s_node_type": "compute"
                }
            }
            
            for idx, ip in enumerate(worker_ips, 1):
                hostname = f"worker{idx}"
                self.inventory["k8s_workers"]["hosts"][hostname] = {
                    "ansible_host": ip
                }
                self.inventory["_meta"]["hostvars"][hostname] = {
                    "ansible_host": ip,
                    "node_name": f"k8s-worker-{2099 + idx}",  # 2100, 2101 и т.д.
                    "node_index": idx
                }
        
        # Создаем группу всех нод
        if "k8s_masters" in self.inventory or "k8s_workers" in self.inventory:
            self.inventory["k8s_cluster"] = {"children": []}
            if "k8s_masters" in self.inventory:
                self.inventory["k8s_cluster"]["children"].append("k8s_masters")
            if "k8s_workers" in self.inventory:
                self.inventory["k8s_cluster"]["children"].append("k8s_workers")
        
        return self.inventory

def main():
    """Основная функция"""
    if len(sys.argv) == 2 and sys.argv[1] == "--list":
        inventory = TerraformInventory().generate_inventory()
        print(json.dumps(inventory, indent=2))
    
    elif len(sys.argv) == 3 and sys.argv[1] == "--host":
        # Для запроса информации о конкретном хосте
        # Можно реализовать позже
        print(json.dumps({}))
    
    else:
        print(f"Usage: {sys.argv[0]} --list | --host <hostname>", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
