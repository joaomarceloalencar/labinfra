# 🧪 Atividade 02 — Laboratório de Infraestrutura de Redes - Roteador Linux no Virtual Box

## Roteiro de Aula — Roteador Linux com NAT, DHCP e Firewall

---

# 🎯 Objetivos da Aula

Ao final da prática, o aluno deverá ser capaz de:

* Configurar interfaces de rede com Netplan
* Implementar um servidor DHCP
* Habilitar roteamento IP no Linux
* Configurar NAT com iptables
* Aplicar regras de firewall com controle de saída (egress filtering)
* Diagnosticar problemas de conectividade

---

# 🧩 Etapa 0 — Topologia

## Visualização

```
[ Internet ]
     |
 (bridge - DHCP)
     |
[ servidor ]
  enp0s3 → Internet
  enp0s8 → 192.168.26.1/24
     |
 (labinfra)
     |
[ desktop ]
  enp0s3 → DHCP
```

---

## ❓ Perguntas iniciais

* Qual interface terá acesso à Internet?
* Qual máquina será o gateway?
* Por que separar redes (labinfra vs Internet)?

---

# ⚙️ Etapa 1 — Configuração de Rede (Servidor)

## Ação

Editar:

```bash
sudo nano /etc/netplan/01-labinfra.yaml
```

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

## ✅ Checkpoint 1

```bash
ip a
```

✔ Deve existir:

* IP dinâmico em `enp0s3`
* IP `192.168.26.1` em `enp0s8`

---

## ❓ Pergunta

* O servidor já consegue acessar a Internet? Por quê?

---

# 🖥️ Etapa 2 — Configuração do Desktop

```yaml
enp0s3:
  dhcp4: true
```

Aplicar:

```bash
sudo netplan apply
```

---

## ✅ Checkpoint 2

```bash
ip a
```

✔ Deve receber IP `192.168.26.x`

---

## ❓ Pergunta

* O desktop já acessa a Internet? Por quê?

---

# 📡 Etapa 3 — Servidor DHCP

## Instalação

```bash
sudo apt install isc-dhcp-server
```

---

## Configuração

Arquivo:

```bash
sudo nano /etc/dhcp/dhcpd.conf
```

```conf
subnet 192.168.26.0 netmask 255.255.255.0 {
    range 192.168.26.100 192.168.26.200;

    option routers 192.168.26.1;
    option domain-name-servers 8.8.8.8;
}
```

---

## Interface

```bash
sudo nano /etc/default/isc-dhcp-server
```

```bash
INTERFACESv4="enp0s8"
```

---

## Ativar

```bash
sudo systemctl restart isc-dhcp-server
```

---

## ✅ Checkpoint 3

```bash
journalctl -u isc-dhcp-server
```

✔ Deve mostrar concessões de IP

---

## ❓ Perguntas

* Quem está atribuindo IP ao desktop agora?
* Qual é o gateway entregue via DHCP?

---

# 🔀 Etapa 4 — Habilitar Roteamento

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

---

## ✅ Checkpoint 4

```bash
sysctl net.ipv4.ip_forward
```

✔ Deve retornar `1`

---

## ❓ Pergunta

* O que acontece se isso estiver desabilitado?

---

# 🌐 Etapa 5 — NAT

```bash
sudo iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
```

---

## ✅ Checkpoint 5

```bash
iptables -t nat -L -v
```

---

## 🧪 Teste

No desktop:

```bash
ping 8.8.8.8
```

✔ Agora deve funcionar

---

## ❓ Pergunta

* Por que o NAT é necessário nesse cenário?

---

# 🔥 Etapa 6 — Firewall Base

## Limpar

```bash
sudo iptables -F
sudo iptables -t nat -F
```

---

## Políticas

```bash
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
```

---

## Regras essenciais

```bash
sudo iptables -A INPUT -i lo -j ACCEPT

sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

---

## ❓ Pergunta

* Por que bloquear INPUT por padrão é uma boa prática?

---

# 🚦 Etapa 7 — Controle de Saída (Egress Filtering)

## Permitir DNS

```bash
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p udp --dport 53 -j ACCEPT
```

---

## Permitir Web

```bash
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp --dport 80 -j ACCEPT
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp --dport 443 -j ACCEPT
```

---

## Bloquear ICMP

```bash
sudo iptables -A FORWARD -i enp0s8 -o enp0s3 -p icmp -j DROP
```

---

## Log

```bash
sudo iptables -A FORWARD -j LOG --log-prefix "DROP_FORWARD: "
```

---

## ✅ Checkpoint 6

No desktop:

```bash
ping 8.8.8.8
curl http://example.com
```

✔ Ping falha
✔ HTTP funciona

---

## ❓ Perguntas

* O que foi bloqueado?
* O que ainda é permitido?
* Qual o papel do DNS?

---

# 🔍 Etapa 8 — Diagnóstico

## No servidor

```bash
iptables -L -v
iptables -t nat -L -v
```

---

## Logs

```bash
dmesg -w
```

---

## ❓ Perguntas

* Como identificar um pacote bloqueado?
* Qual chain foi usada?

---

# 🧠 Exercícios Guiados

## Exercício 1 — Liberar ping

Permita ICMP temporariamente.

---

## Exercício 2 — Bloquear HTTP

Permita apenas HTTPS.

---

## Exercício 3 — Bloquear um host

Bloqueie `192.168.26.150`.

---

## Exercício 4 — Permitir apenas DNS + HTTPS

Remova HTTP completamente.

---

## Exercício 5 — Observação de tráfego

```bash
sudo tcpdump -i enp0s8
```

* O que você vê ao acessar um site?

---

# 🎯 Desafio Final

Implemente:

* Internet funcionando
* Ping bloqueado
* Apenas HTTPS permitido
* DHCP funcionando

---

# 🧾 Checklist Final

| Item                      | Status |
| ------------------------- | ------ |
| DHCP funcionando          | ☐      |
| Roteamento ativo          | ☐      |
| NAT funcionando           | ☐      |
| Firewall ativo            | ☐      |
| Egress filtering aplicado | ☐      |

---

# 💬 Fechamento (Discussão)

* Qual a diferença entre NAT e roteamento?
* O firewall protege quem?
* Esse modelo escala para redes reais?

