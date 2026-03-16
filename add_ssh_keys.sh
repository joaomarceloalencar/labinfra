#!/bin/bash

# IPs com falha de autenticação no inventário
ips=(
    "200.129.39.89"
    "200.129.39.84"
    "200.129.39.83"
    "200.129.39.81"
    "200.129.39.66"
    "200.129.39.79"
    "200.129.39.87"
    "200.129.39.67"
    "200.129.39.71"
    "200.129.39.75"
)

for ip in "${ips[@]}"; do
    echo "=========================================="
    echo "Adicionando chave SSH em: $ip"
    echo "=========================================="
    read -p "Pressione Enter para continuar..."
    ssh-copy-id -o StrictHostKeyChecking=no ufc@$ip
    
    if [ $? -eq 0 ]; then
        echo "Sucesso em $ip"
    else
        echo "Falha em $ip"
    fi
    echo ""
done

echo "Processo concluído!"