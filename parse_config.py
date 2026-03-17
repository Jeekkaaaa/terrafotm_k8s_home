#!/usr/bin/env python3
import re
import json
import sys

def parse_tfvars_to_dict(tfvars_path):
    with open(tfvars_path, 'r') as f:
        content = f.read()

    # ФИКС: Улучшенные регулярные выражения
    # Ищем от начала блока до его закрывающей скобки, игнорируя вложенные блоки
    patterns = {
        'kubernetes_version': r'kubernetes_config\s*=\s*\{[^{}]*(?:{[^{}]*}[^{}]*)*version\s*=\s*"([^"]+)"',
        'pod_network_cidr': r'kubernetes_config\s*=\s*\{[^{}]*(?:{[^{}]*}[^{}]*)*pod_network_cidr\s*=\s*"([^"]+)"',
        'service_cidr': r'kubernetes_config\s*=\s*\{[^{}]*(?:{[^{}]*}[^{}]*)*service_cidr\s*=\s*"([^"]+)"',
        'calico_url': r'cni_config\s*=\s*\{[^{}]*(?:{[^{}]*}[^{}]*)*manifest_url\s*=\s*"([^"]+)"',
        'cluster_name': r'cluster_config\s*=\s*\{[^{}]*(?:{[^{}]*}[^{}]*)*cluster_name\s*=\s*"([^"]+)"',
        'domain': r'cluster_config\s*=\s*\{[^{}]*(?:{[^{}]*}[^{}]*)*domain\s*=\s*"([^"]+)"',
        'subnet': r'network_config\s*=\s*\{[^{}]*(?:{[^{}]*}[^{}]*)*subnet\s*=\s*"([^"]+)"',
        'masters_count': r'cluster_config\s*=\s*\{[^{}]*(?:{[^{}]*}[^{}]*)*masters_count\s*=\s*(\d+)',
        'workers_count': r'cluster_config\s*=\s*\{[^{}]*(?:{[^{}]*}[^{}]*)*workers_count\s*=\s*(\d+)',
    }

    result = {}
    for key, pattern in patterns.items():
        match = re.search(pattern, content, re.DOTALL)
        result[key] = match.group(1).strip() if match else None

    defaults = {
        'kubernetes_version': '1.30',
        'pod_network_cidr': '10.244.0.0/16',
        'service_cidr': '10.96.0.0/12',
        'calico_url': 'https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml',
        'cluster_name': 'home-k8s-cluster',
        'domain': 'home.lab',
        'subnet': '192.168.0.0/24',
        'masters_count': '1',
        'workers_count': '1',
    }

    for key, default in defaults.items():
        if not result.get(key):
            result[key] = default

    # ФИКС: Добавляем очистку от лишних пробелов и переносов строк
    cleaned_result = {}
    for key, value in result.items():
        if isinstance(value, str):
            # Удаляем все лишние пробелы, переносы строк и табуляции
            cleaned_value = re.sub(r'\s+', ' ', value).strip()
            cleaned_result[key] = cleaned_value
        else:
            cleaned_result[key] = value

    return {
        'kubernetes_version': cleaned_result['kubernetes_version'],
        'pod_network_cidr': cleaned_result['pod_network_cidr'],
        'service_cidr': cleaned_result['service_cidr'],
        'cri_socket': 'unix:///var/run/containerd/containerd.sock',
        'calico_manifest_url': cleaned_result['calico_url'],
        'cluster_name': cleaned_result['cluster_name'],
        'cluster_domain': cleaned_result['domain'],
        'network_prefix': cleaned_result['subnet'].split('/')[0].rsplit('.', 1)[0],
        'masters_count': int(cleaned_result['masters_count']),
        'workers_count': int(cleaned_result['workers_count']),
    }

if __name__ == '__main__':
    output_format = 'text'
    config_path = 'config.auto.tfvars'

    for arg in sys.argv[1:]:
        if arg in ['--json', '--env']:
            output_format = arg[2:]
        elif not arg.startswith('-'):
            config_path = arg

    vars = parse_tfvars_to_dict(config_path)

    if output_format == 'json':
        print(json.dumps(vars, indent=2))
    elif output_format == 'env':
        for key, value in vars.items():
            # ФИКС: Для env-формата тоже очищаем строки
            if isinstance(value, str):
                clean_val = value.replace('\n', ' ').strip()
            else:
                clean_val = value
            print(f"{key.upper()}={json.dumps(clean_val)}")
    else:
        for key, value in vars.items():
            print(f"{key}: {json.dumps(value)}")
