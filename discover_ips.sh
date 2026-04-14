#!/bin/bash

# Script para descobrir IPs atuais baseado nos MACs conhecidos
# Executa na máquina 200.129.39.83 que está respondendo

# MACs conhecidos do README.md
declare -A macs_conhecidos=(
    ["d0:94:66:bd:69:6f"]="200.129.39.84"
    ["d0:27:88:c1:ee:e9"]="200.129.39.88"
    ["d0:27:88:c1:f2:c6"]="200.129.39.83"
    ["d0:27:88:c1:f0:87"]="200.129.39.89"
    ["d0:27:88:c1:f0:9a"]="200.129.39.81"
    ["d0:27:88:c2:04:01"]="200.129.39.69"
    ["d0:27:88:c1:f0:03"]="200.129.39.66"
    ["d0:27:88:c1:ef:4e"]="200.129.39.79"
    ["d0:27:88:c1:d3:2f"]="200.129.39.74"
    ["d0:27:88:c1:ee:dc"]="200.129.39.87"
    ["d0:27:88:c1:d3:58"]="200.129.39.67"
    ["d0:27:88:c1:ef:d1"]="200.129.39.71"
    ["d0:27:88:5e:24:a4"]="200.129.39.75"
)

echo "=========================================="
echo "Descobrindo IPs atuais via ARP scan"
echo "=========================================="
echo ""

# Fazer ping broadcast para popular a tabela ARP
echo "Populando tabela ARP (isso pode demorar um pouco)..."
sudo nmap -sn 200.129.39.0/24 > /dev/null 2>&1 || {
    # Fallback se nmap não estiver instalado
    for i in {1..255}; do
        ping -c 1 -W 1 200.129.39.$i > /dev/null 2>&1 &
    done
    wait
}

echo ""
echo "Consultando tabela ARP..."
echo ""

# Ler a tabela ARP
arp_output=$(ip neigh show)

echo "MACs encontrados na rede:"
echo "----------------------------------------"
printf "%-20s | %-17s | %-15s\n" "IP Original" "MAC Address" "IP Atual"
echo "----------------------------------------"

found_count=0
missing_macs=()

for mac in "${!macs_conhecidos[@]}"; do
    ip_original="${macs_conhecidos[$mac]}"
    
    # Buscar o MAC na saída do ARP (case insensitive)
    ip_atual=$(echo "$arp_output" | grep -i "$mac" | awk '{print $1}' | head -1)
    
    if [ -n "$ip_atual" ]; then
        printf "%-20s | %-17s | %-15s\n" "$ip_original" "$mac" "$ip_atual"
        ((found_count++))
    else
        missing_macs+=("$mac ($ip_original)")
    fi
done

echo "----------------------------------------"
echo "Total encontrado: $found_count de ${#macs_conhecidos[@]}"
echo ""

if [ ${#missing_macs[@]} -gt 0 ]; then
    echo "MACs não encontrados:"
    for missing in "${missing_macs[@]}"; do
        echo "  - $missing"
    done
    echo ""
fi

# Gerar novo inventory.ini
echo "Gerando novo inventory.ini..."
echo ""

cat > /tmp/inventory.ini << 'EOF'
[ativos]
EOF

for mac in "${!macs_conhecidos[@]}"; do
    ip_atual=$(echo "$arp_output" | grep -i "$mac" | awk '{print $1}' | head -1)
    if [ -n "$ip_atual" ]; then
        echo "$ip_atual" >> /tmp/inventory.ini
    fi
done

cat >> /tmp/inventory.ini << 'EOF'

[ativos:vars]
ansible_user=ufc
ansible_connection=ssh
EOF

echo "Novo inventory.ini gerado em /tmp/inventory.ini"
echo ""
echo "Conteúdo:"
echo "=========================================="
cat /tmp/inventory.ini
echo "=========================================="
