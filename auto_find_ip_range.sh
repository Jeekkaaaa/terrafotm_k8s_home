#!/bin/bash

CONFIG_FILE="config.auto.tfvars"

# Читаем текущие настройки
SUBNET=$(grep 'subnet' "$CONFIG_FILE" | sed -n 's/.*"\([^"]*\)".*/\1/p')
CURRENT_BASE=$(grep 'static_ip_base' "$CONFIG_FILE" | awk '{print $3}')
MASTERS_COUNT=$(grep -A2 'masters_count' "$CONFIG_FILE" | grep -o '[0-9]\+' | head -1)
WORKERS_COUNT=$(grep -A2 'workers_count' "$CONFIG_FILE" | grep -o '[0-9]\+' | head -1')
TOTAL_NODES=$((MASTERS_COUNT + WORKERS_COUNT))

NETWORK_PREFIX=$(echo "$SUBNET" | cut -d'/' -f1 | awk -F. '{print $1"."$2"."$3}')

echo "Поиск свободного диапазона для $TOTAL_NODES нод..."
echo "Текущий диапазон: $CURRENT_BASE - $((CURRENT_BASE + TOTAL_NODES - 1))"

# Ищем свободный диапазон
for start_ip in $(seq 100 240); do
  ALL_FREE=true
  
  # Проверяем весь диапазон
  for offset in $(seq 0 $((TOTAL_NODES - 1))); do
    ip=$((start_ip + offset))
    if ping -c 1 -W 1 "${NETWORK_PREFIX}.${ip}" &>/dev/null; then
      ALL_FREE=false
      break
    fi
  done
  
  if [ "$ALL_FREE" = true ]; then
    echo "✅ Найден свободный диапазон: $start_ip - $((start_ip + TOTAL_NODES - 1))"
    
    # Обновляем конфиг
    sed -i "s/static_ip_base  = $CURRENT_BASE/static_ip_base  = $start_ip/" "$CONFIG_FILE"
    echo "📝 Обновлен static_ip_base на $start_ip"
    
    # Показываем новые IP
    echo "Новые IP адреса:"
    for offset in $(seq 0 $((TOTAL_NODES - 1))); do
      ip=$((start_ip + offset))
      if [ $offset -lt $MASTERS_COUNT ]; then
        echo "  Мастер $((offset+1)): ${NETWORK_PREFIX}.${ip}"
      else
        worker_num=$((offset - MASTERS_COUNT + 1))
        echo "  Воркер $worker_num: ${NETWORK_PREFIX}.${ip}"
      fi
    done
    exit 0
  fi
done

echo "❌ Не найден свободный диапазон на 240 адресов"
exit 1
