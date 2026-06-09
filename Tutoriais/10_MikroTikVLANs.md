# 🧪 Atividade 10 — Laboratório de Infraestrutura de Redes - Roteamento e VLANs com MikroTik CHR

## Objetivo

Este laboratório introduz o **MikroTik RouterOS** como roteador/gateway em substituição ao pfSense, cobrindo os mesmos cenários das Atividades 04–06 com foco na **linha de comando do RouterOS**. A ênfase está em compreender a CLI do MikroTik, que difere bastante de sistemas Unix.

Ao final, o aluno será capaz de:

* Navegar e operar a CLI do MikroTik (RouterOS)
* Configurar endereçamento IP, DHCP client e DHCP server no MikroTik
* Configurar NAT/masquerade para acesso à Internet
* Criar VLANs como sub-interfaces no MikroTik
* Configurar trunk 802.1Q entre MikroTik e Open vSwitch
* Verificar e diagnosticar a rede com ferramentas do RouterOS

---

## Duração estimada

Aproximadamente **3h**

---

## Pré-requisitos

* Ter concluído as Atividades 04 e 05 (conceitos de switch e VLAN no OVS)
* Templates disponíveis no GNS3:
  * Container: `ubuntu-net` (insightlab/ubuntu-net:1.0)
  * Container: `ubuntu-desktop` (insightlab/ubuntu-desktop:1.0 — console VNC)
  * Switch: Open vSwitch (insightlab/ovs:1.1)
  * Roteador: **MikroTikCHR7.22.1-1** (QEMU)
  * Cloud: NAT

---

## Introdução à CLI do MikroTik

O MikroTik RouterOS possui uma CLI própria, organizada em uma **árvore de menus**. Antes de configurar qualquer coisa, é fundamental entender como navegar nela.

### Acesso ao console

No GNS3, clique duas vezes no nó MikroTik para abrir o console (Telnet). Você verá:

```
MikroTik 7.22.1

Login: admin
Password:           ← pressione Enter (sem senha no primeiro acesso)
```

O prompt após o login será:

```
[admin@MikroTik] >
```

### Estrutura em árvore de menus

Toda a configuração do RouterOS é organizada em caminhos semelhantes a um sistema de arquivos:

```
/                      ← raiz
├── interface          ← interfaces de rede
├── ip
│   ├── address        ← endereços IP
│   ├── route          ← tabela de rotas
│   ├── dhcp-client    ← cliente DHCP (WAN)
│   ├── dhcp-server    ← servidor DHCP
│   ├── firewall
│   │   ├── filter     ← regras de filtro
│   │   └── nat        ← regras de NAT
│   └── pool           ← faixas de endereços
└── system
    └── identity       ← nome do roteador
```

### Como navegar

Há dois estilos equivalentes — escolha o que preferir:

**Estilo 1 — comando completo com caminho absoluto (recomendado para iniciantes):**

```
[admin@MikroTik] > /ip address print
```

**Estilo 2 — entrar no menu e usar comandos relativos:**

```
[admin@MikroTik] > /ip address
[admin@MikroTik] /ip/address> print
[admin@MikroTik] /ip/address> ..     ← sobe um nível
[admin@MikroTik] /ip> /             ← volta à raiz
```

Neste tutorial usaremos sempre o **estilo 1** (caminho absoluto) para clareza.

### Comandos fundamentais

| Comando | Descrição |
|---------|-----------|
| `/interface print` | Lista todas as interfaces |
| `/ip address print` | Mostra endereços IP configurados |
| `/ip route print` | Mostra a tabela de rotas |
| `/ip dhcp-client print` | Mostra status do cliente DHCP |
| `/ip dhcp-server print` | Lista servidores DHCP configurados |
| `/ip firewall nat print` | Mostra regras de NAT |
| `ping 8.8.8.8` | Testa conectividade (a partir de qualquer posição) |
| `?` | Lista subcomandos do nível atual |
| `Tab` | Autocompleta comandos e parâmetros |

### Adicionando, modificando e removendo

Todo menu usa os mesmos verbos:

```
/ip address add address=10.0.0.1/24 interface=ether2   ← adiciona
/ip address set [find interface=ether2] address=10.0.0.5/24  ← modifica
/ip address remove [find interface=ether2]              ← remove
```

O `[find ...]` é um filtro inline — ele seleciona o item cujo campo corresponde ao valor informado. É equivalente a "encontre o item onde `interface=ether2`".

### Identificar o nome do roteador

Para facilitar a leitura do prompt, é boa prática nomear o roteador:

```
/system identity set name=GW-MikroTik
```

O prompt mudará para `[admin@GW-MikroTik] >`.

---

## Parte 1 — Rede plana: MikroTik como gateway com DHCP

### Objetivo

Configurar o MikroTik como gateway de uma rede plana (sem VLANs), com DHCP server para os hosts e NAT para acesso à Internet.

---

### Topologia

```
          [ NAT do GNS3 ]
                |
           ether1 (WAN)
          [ MikroTik ]
           ether2 (LAN) 10.0.0.1/24
                |
          [ Open vSwitch ]
         /       |        \
      eth2     eth3       eth4
       |         |          |
    [PC1]    [PC2]    [Desktop]
  ubuntu-net ubuntu-net ubuntu-desktop
```

### Tabela de endereçamento

| Dispositivo | Interface | IP | Método |
|-------------|-----------|-----|--------|
| MikroTik | ether1 (WAN) | DHCP via NAT | dhcp-client |
| MikroTik | ether2 (LAN) | 10.0.0.1/24 | estático |
| PC1 | eth0 | 10.0.0.100–200 | DHCP |
| PC2 | eth0 | 10.0.0.100–200 | DHCP |
| Desktop | eth0 | 10.0.0.100–200 | DHCP |

---

### Passos — Montar a topologia no GNS3

1. Adicione ao projeto:
   * 1 **NAT** (cloud)
   * 1 **MikroTikCHR7.22.1-1** (QEMU)
   * 1 **Open vSwitch**
   * 2 containers **ubuntu-net**: PC1 e PC2
   * 1 container **ubuntu-desktop**: Desktop

2. Conecte:
   * **NAT** → **MikroTik** porta `e0` (será ether1 no RouterOS)
   * **MikroTik** porta `e1` → **OVS** `eth1`
   * **PC1** `eth0` → **OVS** `eth2`
   * **PC2** `eth0` → **OVS** `eth3`
   * **Desktop** `eth0` → **OVS** `eth4`

3. Inicie todos os dispositivos.

> **Lembrete:** nunca utilize `eth0` do switch OVS.

---

### Configurar o Open vSwitch

Nesta parte, o OVS opera como switch L2 simples — nenhuma configuração de VLAN é necessária. As interfaces já são adicionadas ao bridge `br0` pelo `start.sh` da imagem.

Verifique apenas que as portas estão no bridge:

```bash
ovs-vsctl show
```

---

### Configurar o MikroTik

Abra o console do MikroTik (duplo clique no GNS3). Faça login com `admin` e senha em branco.

#### Passo 1 — Nomear o roteador

```
/system identity set name=GW-MikroTik
```

#### Passo 2 — Verificar interfaces disponíveis

```
/interface print
```

Saída esperada:

```
Flags: D - dynamic, X - disabled, R - running
 #   NAME      TYPE   ACTUAL-MTU
 0 R ether1    ether  1500        ← WAN (conectada ao NAT)
 1 R ether2    ether  1500        ← LAN (conectada ao OVS)
```

> **Nota:** o RouterOS nomeia automaticamente as interfaces como `ether1`, `ether2`, etc., na ordem das portas do template QEMU.

#### Passo 3 — Configurar WAN com DHCP client

A interface `ether1` receberá IP do NAT do GNS3 via DHCP:

```
/ip dhcp-client add interface=ether1 disabled=no
```

Verifique que o IP foi obtido:

```
/ip dhcp-client print
```

Saída esperada (após alguns segundos):

```
 #   INTERFACE  USE-PEER-DNS  ADD-DEFAULT-ROUTE  STATUS   ADDRESS
 0   ether1     yes           yes                bound    192.168.122.x/24
```

O status `bound` confirma que o DHCP funcionou.

#### Passo 4 — Configurar LAN com IP estático

```
/ip address add address=10.0.0.1/24 interface=ether2
```

Verifique:

```
/ip address print
```

```
Flags: D - dynamic
 #   ADDRESS        NETWORK    INTERFACE
 0 D 192.168.122.x  192.168.122.0  ether1    ← obtido por DHCP
 1   10.0.0.1/24    10.0.0.0       ether2    ← configurado manualmente
```

#### Passo 5 — Configurar pool de endereços DHCP

O pool define a faixa de IPs que o servidor DHCP poderá distribuir:

```
/ip pool add name=lan-pool ranges=10.0.0.100-10.0.0.200
```

#### Passo 6 — Criar o servidor DHCP

```
/ip dhcp-server add name=lan-dhcp interface=ether2 address-pool=lan-pool disabled=no
```

#### Passo 7 — Configurar a rede do DHCP (gateway e DNS)

Este passo informa ao servidor quais informações entregar aos clientes junto com o IP:

```
/ip dhcp-server network add address=10.0.0.0/24 gateway=10.0.0.1 dns-server=8.8.8.8,1.1.1.1
```

Verifique o servidor DHCP:

```
/ip dhcp-server print
/ip dhcp-server network print
```

#### Passo 8 — Configurar NAT (masquerade)

O NAT faz com que os hosts da LAN possam acessar a Internet usando o IP da WAN do MikroTik:

```
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
```

Explicação dos parâmetros:
* `chain=srcnat` — regra aplicada ao tráfego originado internamente
* `out-interface=ether1` — aplica ao tráfego saindo pela WAN
* `action=masquerade` — substitui o IP de origem pelo IP da WAN automaticamente

Verifique:

```
/ip firewall nat print
```

#### Resumo da configuração (verificação final)

```
/interface print
/ip address print
/ip dhcp-client print
/ip dhcp-server print
/ip route print
/ip firewall nat print
```

---

### Configurar os hosts

#### PC1 e PC2 (ubuntu-net)

O container `ubuntu-net` tem `isc-dhcp-client` instalado. No terminal de cada um:

```bash
dhclient eth0
ip addr show eth0
ip route
```

Verifique que recebeu IP na faixa `10.0.0.100–200` e que o gateway é `10.0.0.1`.

#### Desktop (ubuntu-desktop)

O container executa `dhclient` automaticamente ao iniciar. Abra o console VNC no GNS3 e, no xterm:

```bash
ip addr show eth0
```

Se necessário, renove manualmente:

```bash
dhclient eth0
```

---

### Testes

#### Conectividade local

```bash
# De PC1 — ping no gateway
ping -c 3 10.0.0.1

# De PC1 — ping em PC2
ping -c 3 <IP do PC2>

# De PC1 — ping no Desktop
ping -c 3 <IP do Desktop>
```

#### Acesso à Internet

```bash
# De qualquer host
ping -c 3 8.8.8.8

# Resolução DNS
ping -c 3 google.com
```

#### Verificar leases DHCP no MikroTik

```
/ip dhcp-server lease print
```

Mostrará todos os IPs distribuídos, junto com os endereços MAC dos clientes.

---

### Perguntas

* Qual a diferença entre `/ip dhcp-client` e `/ip dhcp-server` no MikroTik?
* Por que a regra de NAT usa `out-interface=ether1` e não `ether2`?
* O que acontece se você remover a regra de NAT? Teste e verifique.
* Como o MikroTik sabe para qual host entregar qual IP no DHCP?

---

## Parte 2 — VLANs no MikroTik com trunk para o OVS

### Objetivo

Estender a topologia anterior com duas VLANs: **VLAN 10** (Gestão, com Desktop) e **VLAN 20** (Alunos). O MikroTik cria sub-interfaces VLAN sobre `ether2` e o OVS é reconfigurado com trunk.

---

### Topologia

```
         [ NAT do GNS3 ]
               |
          ether1 (WAN)
         [ MikroTik ]
    ether2 (trunk: VLAN 10, 20)
               |
         [ Open vSwitch ]
     eth1 = trunk(10,20)
    /        |          |         \
  eth2     eth3       eth4       eth5
tag=10   tag=10     tag=20     tag=20
  |         |          |          |
[Admin]  [Desktop]  [Aluno1]  [Aluno2]
```

### Tabela de endereçamento

| Dispositivo | VLAN | Interface | IP | Método |
|-------------|------|-----------|----|--------|
| MikroTik | — | ether1 (WAN) | DHCP via NAT | dhcp-client |
| MikroTik | 10 | vlan10 | 10.0.10.1/24 | estático |
| MikroTik | 20 | vlan20 | 10.0.20.1/24 | estático |
| Admin | 10 | eth0 | 10.0.10.100–200 | DHCP |
| Desktop | 10 | eth0 | 10.0.10.100–200 | DHCP |
| Aluno1 | 20 | eth0 | 10.0.20.100–200 | DHCP |
| Aluno2 | 20 | eth0 | 10.0.20.100–200 | DHCP |

---

### Passos — Atualizar a topologia no GNS3

Renomeie os nós existentes e adicione mais um host:

1. Renomeie `PC1` → `Admin`
2. Renomeie `PC2` → `Aluno1`
3. Adicione 1 container **ubuntu-net**: `Aluno2`
4. Conecte `Aluno2` `eth0` → **OVS** `eth5`

---

### Reconfigurar o Open vSwitch

Remova as configurações anteriores e aplique as novas:

```bash
# Remover tags antigas (se houver)
ovs-vsctl clear port eth2 tag
ovs-vsctl clear port eth3 tag
ovs-vsctl clear port eth4 tag

# Porta trunk conectada ao MikroTik — transporta VLAN 10 e 20
ovs-vsctl set port eth1 trunks=10,20

# VLAN 10 — Gestão (Admin e Desktop)
ovs-vsctl set port eth2 tag=10
ovs-vsctl set port eth3 tag=10

# VLAN 20 — Alunos
ovs-vsctl set port eth4 tag=20
ovs-vsctl set port eth5 tag=20
```

Verifique:

```bash
ovs-vsctl show
```

---

### Reconfigurar o MikroTik

#### Passo 1 — Remover a configuração LAN da Parte 1

```
/ip dhcp-server remove [find name=lan-dhcp]
/ip dhcp-server network remove [find address=10.0.0.0/24]
/ip pool remove [find name=lan-pool]
/ip address remove [find interface=ether2]
```

Confirme que foi removido:

```
/ip address print
/ip dhcp-server print
```

#### Passo 2 — Criar as interfaces VLAN

No MikroTik, VLANs são criadas como **interfaces virtuais** sobre a interface física. Cada interface VLAN processa apenas os quadros 802.1Q com a tag correspondente:

```
/interface vlan add name=vlan10 vlan-id=10 interface=ether2
/interface vlan add name=vlan20 vlan-id=20 interface=ether2
```

Verifique as interfaces criadas:

```
/interface print
```

```
Flags: D - dynamic, X - disabled, R - running
 #   NAME    TYPE   ACTUAL-MTU
 0 R ether1  ether  1500
 1 R ether2  ether  1500
 2 R vlan10  vlan   1500       ← sub-interface para VLAN 10
 3 R vlan20  vlan   1500       ← sub-interface para VLAN 20
```

> **Como funciona:** quando o OVS envia um quadro tagueado com `vlan 10` pela porta trunk, o MikroTik o recebe em `ether2` e o entrega à interface `vlan10`. O tráfego da `vlan20` é entregue à `vlan20`. A interface física `ether2` em si não recebe IP — funciona apenas como portadora das sub-interfaces.

#### Passo 3 — Atribuir IPs às interfaces VLAN

```
/ip address add address=10.0.10.1/24 interface=vlan10
/ip address add address=10.0.20.1/24 interface=vlan20
```

Verifique:

```
/ip address print
```

```
 #   ADDRESS         NETWORK     INTERFACE
 0 D 192.168.122.x   192.168.122.0  ether1
 1   10.0.10.1/24    10.0.10.0      vlan10
 2   10.0.20.1/24    10.0.20.0      vlan20
```

#### Passo 4 — Criar pools de endereços DHCP

```
/ip pool add name=vlan10-pool ranges=10.0.10.100-10.0.10.200
/ip pool add name=vlan20-pool ranges=10.0.20.100-10.0.20.200
```

#### Passo 5 — Criar servidores DHCP por VLAN

```
/ip dhcp-server add name=vlan10-dhcp interface=vlan10 address-pool=vlan10-pool disabled=no
/ip dhcp-server add name=vlan20-dhcp interface=vlan20 address-pool=vlan20-pool disabled=no
```

#### Passo 6 — Configurar rede DHCP por VLAN (gateway e DNS)

```
/ip dhcp-server network add address=10.0.10.0/24 gateway=10.0.10.1 dns-server=8.8.8.8,1.1.1.1
/ip dhcp-server network add address=10.0.20.0/24 gateway=10.0.20.1 dns-server=8.8.8.8,1.1.1.1
```

Verifique tudo:

```
/ip dhcp-server print
/ip dhcp-server network print
```

#### Passo 7 — NAT (a regra da Parte 1 continua válida)

A regra de masquerade `out-interface=ether1` cobre automaticamente tráfego de todas as VLANs, pois o IP de destino sempre sai por `ether1`. Nenhuma mudança necessária.

Confirme:

```
/ip firewall nat print
```

---

### Configurar os hosts

#### Admin (ubuntu-net, VLAN 10)

```bash
dhclient eth0
ip addr show eth0
```

Verifique IP na faixa `10.0.10.100–200` e gateway `10.0.10.1`.

#### Desktop (ubuntu-desktop, VLAN 10)

Abra o console VNC no GNS3. No xterm:

```bash
dhclient eth0
ip addr show eth0
```

#### Aluno1 e Aluno2 (ubuntu-net, VLAN 20)

```bash
dhclient eth0
ip addr show eth0
```

Verifique IP na faixa `10.0.20.100–200` e gateway `10.0.20.1`.

---

### Testes — Conectividade dentro de cada VLAN

```bash
# De Admin → Desktop (VLAN 10): deve funcionar
ping -c 3 <IP do Desktop>

# De Aluno1 → Aluno2 (VLAN 20): deve funcionar
ping -c 3 <IP do Aluno2>
```

### Testes — Isolamento entre VLANs

```bash
# De Admin → Aluno1 (VLAN 10 → VLAN 20): deve funcionar via MikroTik (roteado)
ping -c 3 <IP do Aluno1>
```

> **Atenção:** diferente do OVS (que opera em L2), o MikroTik roteia entre VLANs por padrão. O tráfego entre VLAN 10 e VLAN 20 é **permitido** a menos que uma regra de firewall o bloqueie. Isso é chamado de **inter-VLAN routing**.

### Testes — Acesso à Internet

```bash
# De qualquer host
ping -c 3 8.8.8.8
ping -c 3 google.com
```

---

### Verificações no MikroTik

```
# Leases DHCP atribuídos por VLAN
/ip dhcp-server lease print

# Tabela de rotas (confirmar redes das VLANs)
/ip route print

# Estatísticas de tráfego por interface
/interface monitor-traffic vlan10,vlan20 once
```

---

### Perguntas

* Por que a interface `ether2` não recebe IP nessa configuração, ao contrário da Parte 1?
* Se o OVS não tivesse a porta `eth1` como trunk, o que aconteceria com o tráfego das VLANs?
* Por padrão, o MikroTik permite ou bloqueia o roteamento entre VLANs? Como você verificaria isso?
* Qual é o caminho que um pacote de Admin (10.0.10.x) percorre até chegar em Aluno1 (10.0.20.x)?

---

## Parte 3 — Desafio: controle de tráfego inter-VLAN

### Cenário

> *"Por política de segurança, os Alunos (VLAN 20) devem ter acesso à Internet, mas não podem iniciar conexões com a rede de Gestão (VLAN 10). A Gestão tem acesso irrestrito."*

### Requisitos

| Origem | Destino | Resultado esperado |
|--------|---------|-------------------|
| Admin | Aluno1 | ✅ Deve funcionar |
| Admin | Internet | ✅ Deve funcionar |
| Aluno1 | Internet | ✅ Deve funcionar |
| Aluno1 | Admin | ❌ Deve falhar |
| Desktop | Internet | ✅ Deve funcionar |

### Conceito: Firewall no MikroTik

O firewall do RouterOS usa três **chains** principais:

| Chain | Quando é avaliada |
|-------|------------------|
| `input` | Tráfego destinado ao próprio roteador |
| `forward` | Tráfego passando pelo roteador (entre interfaces) |
| `output` | Tráfego originado pelo próprio roteador |

Para bloquear Alunos de acessar a rede de Gestão, usamos `chain=forward`:

```
/ip firewall filter add \
    chain=forward \
    connection-state = established,related \
    action=accept

/ip firewall filter add \
    chain=forward \  
    in-interface=vlan20 \
    out-interface=vlan10 \
    action=drop \
    comment="Bloquear Alunos -> Gestão"
```

Verifique:

```
/ip firewall filter print
```

### Validação

```bash
# De Aluno1 → Admin: deve FALHAR
ping -c 3 <IP do Admin>

# De Aluno1 → Internet: deve FUNCIONAR
ping -c 3 8.8.8.8

# De Admin → Aluno1: deve FUNCIONAR
ping -c 3 <IP do Aluno1>
```

### Perguntas

* A regra usa `chain=forward`. Por que não `chain=input`?
* Se um Aluno fizer ping no gateway (`10.0.20.1`), a regra o bloqueará? Por quê?
* Como você removeria a regra se precisasse desfazer o bloqueio?

---

## Entregável

* Print da topologia montada no GNS3 (Partes 1 e 2)
* Print do `/ip address print` e `/ip dhcp-server print` do MikroTik em cada parte
* Print dos testes de ping (dentro da VLAN, entre VLANs e para a Internet)
* Print do `/ip dhcp-server lease print` mostrando os leases ativos
* Print da regra de firewall e dos testes do desafio
* Respostas às perguntas de cada parte

---

## Conceitos abordados

| Conceito | Onde foi abordado |
|----------|-------------------|
| CLI do RouterOS | Introdução, todas as partes |
| DHCP client (WAN) | Parte 1 — Passo 3 |
| DHCP server | Partes 1 e 2 |
| NAT / masquerade | Parte 1 — Passo 8 |
| Interface VLAN (sub-interface) | Parte 2 — Passo 2 |
| Trunk 802.1Q (OVS) | Parte 2 |
| Inter-VLAN routing | Partes 2 e 3 |
| Firewall (chain forward) | Parte 3 |

---

## Referência rápida de comandos MikroTik

```
# Listar interfaces
/interface print

# Endereços IP
/ip address print
/ip address add address=X.X.X.X/M interface=etherN
/ip address remove [find interface=etherN]

# DHCP client (WAN)
/ip dhcp-client add interface=ether1 disabled=no
/ip dhcp-client print

# Pool de IPs
/ip pool add name=NOME ranges=X.X.X.X-Y.Y.Y.Y

# DHCP server
/ip dhcp-server add name=NOME interface=etherN address-pool=POOL disabled=no
/ip dhcp-server network add address=X.X.X.X/M gateway=GW dns-server=DNS
/ip dhcp-server lease print

# NAT
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
/ip firewall nat print

# Interface VLAN
/interface vlan add name=vlanN vlan-id=N interface=etherX
/interface print

# Firewall (filtro inter-VLAN)
/ip firewall filter add chain=forward in-interface=vlanX out-interface=vlanY action=drop
/ip firewall filter print

# Rotas
/ip route print

# Diagnóstico
ping X.X.X.X
/tool traceroute X.X.X.X
/interface monitor-traffic ether1 once
```

---

## Próximos passos

* Roteamento estático entre dois MikroTiks
* Firewall com regras stateful (connection-state)
* OSPF no MikroTik
* VPN site-a-site com WireGuard
