# Laboratório de Infraestrutura de Redes

## Roteador Linux com NAT, DHCP e Firewall (iptables)

---

# 1. Topologia

```
[ Internet ]
     |
 (bridge - DHCP)
     |
[ servidor ]
  enp0s3 → DHCP (Internet)
  enp0s8 → 192.168.26.1/24
     |
 (labinfra)
     |
[ desktop ]
  enp0s3 → DHCP
```

* Rede interna: `192.168.26.0/24`
* Gateway: `192.168.26.1`

---

# 2. Netplan — Servidor

Arquivo: `/etc/netplan/01-labinfra.yaml`

```yaml
network:
  version: 2
  renderer: networkd

  ethernets:
    enp0s3:
      dhcp4: true

    enp0s8:
      dhcp4: false
      addresses:
        - 192.168.26.1/24
```

Aplicar:

```bash
sudo netplan apply
```

---

# 3. DHCP Server

## Instalação

```bash
sudo apt update
sudo apt install isc-dhcp-server
```

---

## Definir interface

Arquivo: `/etc/default/isc-dhcp-server`

```bash
INTERFACESv4="enp0s8"
```

---

## Configuração

Arquivo: `/etc/dhcp/dhcpd.conf`

```conf
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 192.168.26.0 netmask 255.255.255.0 {
    range 192.168.26.100 192.168.26.200;

    option routers 192.168.26.1;
    option domain-name-servers 8.8.8.8, 1.1.1.1;
    option broadcast-address 192.168.26.255;
}
```

---

## Ativar serviço

```bash
sudo systemctl enable isc-dhcp-server
sudo systemctl restart isc-dhcp-server
```

Verificar:

```bash
systemctl status isc-dhcp-server
journalctl -u isc-dhcp-server
```

---

# 4. Netplan — Desktop

Arquivo: `/etc/netplan/01-labinfra.yaml`

```yaml
network:
  version: 2
  renderer: NetworkManager

  ethernets:
    enp0s3:
      dhcp4: true
```

Aplicar:

```bash
sudo netplan apply
```

---

# 5. Habilitar Roteamento

## Temporário

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

## Persistente

Editar `/etc/sysctl.conf`:

```bash
net.ipv4.ip_forward=1
```

Aplicar:

```bash
sudo sysctl -p
```

---

# 6. Firewall e NAT (iptables)

## Limpar regras

```bash
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
```

---

## Políticas padrão

```bash
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
```

---

## Loopback

```bash
sudo iptables -A INPUT -i lo -j ACCEPT
```

---

## Conexões estabelecidas

```bash
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
```

---

## SSH

```bash
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

---

## NAT

```bash
sudo iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
```

---

# 7. Controle de Saída (Egress Filtering)

## DNS

```bash
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p udp --dport 53 -j ACCEPT
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp --dport 53 -j ACCEPT
```

---

## HTTP

```bash
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp --dport 80 -j ACCEPT
```

---

## HTTPS

```bash
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp --dport 443 -j ACCEPT
```

---

## Bloquear ICMP (opcional)

```bash
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p icmp -j DROP
```

---

## Permitir acesso da rede interna ao servidor

```bash
sudo iptables -A INPUT -i enp0s8 -j ACCEPT
```

---

## Log de pacotes bloqueados

```bash
sudo iptables -A FORWARD -j LOG --log-prefix "DROP_FORWARD: "
```

---

# 8. Persistência

## Instalar

```bash
sudo apt install iptables-persistent
```

---

## Salvar regras

```bash
sudo netfilter-persistent save
```

---

## Recarregar

```bash
sudo netfilter-persistent reload
```

---

# 9. Testes

## No desktop

```bash
ping 192.168.26.1
ping 8.8.8.8
curl http://example.com
curl https://google.com
dig google.com
```

---

## Diagnóstico

| Teste                 | Significado            |
| --------------------- | ---------------------- |
| ping gateway falha    | problema de rede local |
| ping IP externo falha | NAT/roteamento         |
| DNS falha             | configuração de DNS    |

---

# 10. Verificações importantes

```bash
ip a
ip route
sudo iptables -L -v
sudo iptables -t nat -L -v
sysctl net.ipv4.ip_forward
```

---

# 11. Observação (Ubuntu 24.04)

Para garantir uso do iptables clássico:

```bash
sudo update-alternatives --config iptables
```

Escolher:

```
iptables-legacy
```

---

# Resultado esperado

* DHCP funcional
* Roteamento ativo
* NAT funcionando
* Firewall com controle de saída
* Ambiente pronto para experimentação


