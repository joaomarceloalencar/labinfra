# 🧪 Atividade 06 — Laboratório de Infraestrutura de Redes - pfSense com VLANs

## Objetivo

Este laboratório tem como objetivo configurar um firewall/roteador pfSense integrado com VLANs no Open vSwitch, utilizando uma única interface física em modo trunk para servir duas redes isoladas.

Ao final, o aluno será capaz de:

* Configurar uma porta trunk no Open vSwitch
* Criar VLANs no pfSense sobre uma interface trunk
* Configurar endereçamento IP manual em hosts de diferentes VLANs
* Ativar DHCP no pfSense para cada VLAN
* Validar isolamento entre VLANs e acesso à Internet via NAT

---

## Duração estimada

Aproximadamente **3h**

---

## Pré-requisitos

* Ter concluído o Laboratório 01 (Partes 1 a 4)
* Templates disponíveis no GNS3:
  * Container: `ubuntu-net` (insightlab/ubuntu-net:1.0)
  * Máquina virtual: `UbuntuDesktop` (QEMU — com interface gráfica e Firefox)
  * Switch: Open vSwitch (insightlab/ovs:1.1)
  * Roteador/Firewall: pfSense (pfsense-base.qcow2)
  * Cloud: NAT

---

## Conceitos importantes

### O que é uma porta trunk?

No Laboratório 01, configuramos portas **access** no switch. Uma porta access pertence a uma única VLAN e envia/recebe quadros sem tag.

Uma porta **trunk** é diferente: ela transporta tráfego de **múltiplas VLANs** simultaneamente. Para isso, cada quadro Ethernet que passa pela porta trunk carrega uma **tag 802.1Q** identificando a qual VLAN pertence.

```
Porta ACCESS (tag=1000):          Porta TRUNK (trunks=1000,2000):
  quadro entra sem tag              quadros entram/saem COM tag
  switch adiciona tag internamente  dispositivo na ponta deve
  quadro sai sem tag                entender e tratar as tags
```

O pfSense, conectado a uma porta trunk, cria **sub-interfaces virtuais** — uma para cada VLAN — e pode atuar como gateway de todas elas usando uma única conexão física.

### Por que usar trunk com pfSense?

Em redes reais, é comum um roteador/firewall servir múltiplas VLANs por uma única porta trunk. Isso é chamado de **router-on-a-stick** e evita a necessidade de uma interface física para cada VLAN.

---

## Parte 1 — Topologia e conexões

### Topologia

```
                          [ NAT do GNS3 ]
                                |
                              (WAN)
                           [ pfSense ]
                              (LAN)
                                |
                          trunk (1000,2000)
                                |
   +----------- [ Open vSwitch (OVS) ] -----------+
   |              |              |                 |
 tag=1000      tag=1000       tag=2000          tag=2000
   |              |              |                 |
 [Admin1]  [UbuntuDesktop]   [Aluno1]           [Aluno2]
```

### Tabela de endereçamento

| Dispositivo | VLAN | Interface | IP | Papel |
|-------------|------|-----------|----|-------|
| pfSense | — | WAN (em0) | DHCP (via NAT) | Acesso à Internet |
| pfSense | 1000 | LAN (em1.1000) | 10.0.0.1/24 | Gateway Administração |
| pfSense | 2000 | OPT1 (em1.2000) | 10.0.1.1/24 | Gateway Alunos |
| Admin1 | 1000 | eth0 | 10.0.0.10/24 | Host administração (terminal) |
| UbuntuDesktop | 1000 | eth0 | 10.0.0.11/24 | Host administração (interface gráfica / Firefox) |
| Aluno1 | 2000 | eth0 | 10.0.1.10/24 | Host alunos |
| Aluno2 | 2000 | eth0 | 10.0.1.11/24 | Host alunos |

---

### Passos — Montar a topologia no GNS3

1. Adicione ao projeto:
   * 1 **NAT** (cloud)
   * 1 **pfSense** (QEMU — pfsense-base)
   * 1 **Open vSwitch** (OVS)
   * 3 containers **ubuntu-net** (renomeie para Admin1, Aluno1, Aluno2)
   * 1 máquina virtual **UbuntuDesktop** (QEMU)

2. Conecte:
   * **NAT** → **pfSense** interface `e0` (WAN)
   * **pfSense** interface `e1` (LAN) → **OVS** interface `eth1`
   * **Admin1** eth0 → **OVS** `eth2`
   * **UbuntuDesktop** eth0 → **OVS** `eth3`
   * **Aluno1** eth0 → **OVS** `eth4`
   * **Aluno2** eth0 → **OVS** `eth5`

> **Lembrete:** nunca utilizar `eth0` do switch OVS.

3. Inicie todos os dispositivos.

---

### Perguntas

* Quantas interfaces físicas o pfSense possui nesta topologia?
* Como o pfSense conseguirá servir duas redes com apenas uma interface LAN?

---

## Parte 2 — Configurar o Open vSwitch

### Objetivo

Configurar a porta conectada ao pfSense como trunk e as portas dos hosts como access.

---

### Configuração das portas access (hosts)

No terminal do OVS:

```bash
# VLAN 1000 — Administração
ovs-vsctl set port eth2 tag=1000
ovs-vsctl set port eth3 tag=1000

# VLAN 2000 — Alunos
ovs-vsctl set port eth4 tag=2000
ovs-vsctl set port eth5 tag=2000
```

---

### Configuração da porta trunk (pfSense)

```bash
ovs-vsctl set port eth1 trunks=1000,2000
```

Este comando configura `eth1` para aceitar **apenas** tráfego das VLANs 1000 e 2000, mantendo as tags 802.1Q nos quadros.

---

### Verificação

```bash
ovs-vsctl show
```

Deve mostrar:

* `eth1` com `trunks: [1000, 2000]`
* `eth2` e `eth3` com `tag: 1000`
* `eth4` e `eth5` com `tag: 2000`

---

### Perguntas

* Qual a diferença entre o comando `tag=` e `trunks=`?
* O que acontece se um host na VLAN 1000 enviar um quadro? Ele chega com ou sem tag ao pfSense?
* E se configurássemos a porta do pfSense como access, o que aconteceria?

---

## Parte 3 — Configurar o pfSense pelo console

### Objetivo

Criar as VLANs e atribuir as interfaces do pfSense diretamente pelo console, usando a opção **Assign Interfaces**.

---

### Passo 1 — Atribuição de interfaces e criação de VLANs

No console do pfSense, selecione a opção **1) Assign Interfaces**.

O pfSense perguntará se deseja configurar VLANs agora:

```
Should VLANs be set up now [y|n]?
```

Responda **y**.

#### Criar VLAN 1000 (Administração)

```
Enter the parent interface name for the new VLAN (or nothing if finished): em1
Enter the VLAN tag (1 to 4094): 1000
```

#### Criar VLAN 2000 (Alunos)

```
Enter the parent interface name for the new VLAN (or nothing if finished): em1
Enter the VLAN tag (1 to 4094): 2000
```

#### Finalizar

```
Enter the parent interface name for the new VLAN (or nothing if finished): [Enter]
```

---

### Passo 2 — Atribuir as interfaces

Após criar as VLANs, o pfSense solicitará a atribuição de cada interface:

```
Enter the WAN interface name or 'a' for auto-detection: em0
Enter the LAN interface name or 'a' for auto-detection: em1.1000
Enter the Optional 1 interface name or 'a' for auto-detection (or nothing if finished): em1.2000
Enter the Optional 2 interface name or 'a' for auto-detection (or nothing if finished): [Enter]
```

Confirme quando perguntado:

```
Do you want to proceed [y|n]? y
```

> Após a confirmação, `em1.1000` passa a ser a **LAN** (Administração) e `em1.2000` passa a ser **OPT1** (Alunos). A interface física `em1` não recebe IP diretamente — todo o tráfego passa pelas sub-interfaces VLAN.

---

### Passo 3 — Configurar os IPs das interfaces

Selecione a opção **2) Set interface(s) IP address**.

#### LAN (VLAN 1000 — Administração)

Escolha a interface **LAN** e configure:

```
Enter the new LAN IPv4 address: 10.0.0.1
Enter the new LAN IPv4 subnet bit count: 24
For a WAN, enter the upstream gateway address.
For all other interfaces, press <ENTER> for none: [Enter]
Do you want to enable the DHCP server on LAN? [y|n]: y
Enter the start address of the client address range: 10.0.0.100
Enter the end address of the client address range: 10.0.0.200
```

Quando perguntar sobre HTTP para o webConfigurator: responda **y**.

#### OPT1 (VLAN 2000 — Alunos)

Repita a opção **2** e escolha a interface **OPT1**:

```
Enter the new OPT1 IPv4 address: 10.0.1.1
Enter the new OPT1 IPv4 subnet bit count: 24
For a WAN, enter the upstream gateway address.
For all other interfaces, press <ENTER> for none: [Enter]
Do you want to enable the DHCP server on OPT1? [y|n]: y
Enter the start address of the client address range: 10.0.1.100
Enter the end address of the client address range: 10.0.1.200
```

---

### Verificação

O console do pfSense exibirá um resumo semelhante a:

```
WAN  (em0)      ->  IP via DHCP (NAT)
LAN  (em1.1000) ->  10.0.0.1/24
OPT1 (em1.2000) ->  10.0.1.1/24
```

---

### Perguntas

* Por que a interface física `em1` não recebe IP diretamente nessa configuração?
* Qual a vantagem de configurar VLANs pelo console em vez da interface web?
* O que aconteceria se atribuíssemos `em1` (sem tag VLAN) como LAN?

---

## Parte 4 — Configurar os hosts (IP manual)

### Objetivo

Atribuir IPs manualmente aos hosts e testar conectividade dentro de cada VLAN e com o gateway.

---

### Admin1

```bash
ip addr add 10.0.0.10/24 dev eth0
ip link set eth0 up
ip route add default via 10.0.0.1
```

### UbuntuDesktop

Como o DHCP já está ativo na VLAN 1000, o UbuntuDesktop deve receber IP automaticamente ao iniciar. Basta desativar e reativar a interface de rede:

```bash
nmcli con down "Wired connection 1" && nmcli con up "Wired connection 1"
```

Ou pela interface gráfica: desative e reative a conexão cabeada nas **Configurações de Rede**.

Verifique se o IP está na faixa `10.0.0.100–10.0.0.200`:

```bash
ip addr show eth0
ip route
```

> As instruções abaixo são apenas por precaução, caso o IP não seja atribuído automaticamente. Se o DHCP funcionar, não é necessário configurar manualmente.

O UbuntuDesktop usa NetworkManager. Configure o IP pelo terminal ou pela interface gráfica.

**Pelo terminal:**

```bash
nmcli con mod "Wired connection 1" ipv4.addresses 10.0.0.11/24 ipv4.gateway 10.0.0.1 ipv4.dns "8.8.8.8" ipv4.method manual
nmcli con up "Wired connection 1"
```

**Pela interface gráfica:**

1. Abra as **Configurações de Rede** (Network Settings)
2. Clique no ícone de engrenagem da interface cabeada
3. Na aba **IPv4**, selecione **Manual**
4. Preencha:
   * **Endereço:** `10.0.0.11`
   * **Máscara:** `255.255.255.0`
   * **Gateway:** `10.0.0.1`
   * **DNS:** `8.8.8.8`
5. Clique em **Aplicar** e reconecte a interface

Verifique:

```bash
ip addr show eth0
ip route
```

### Aluno1

```bash
ip addr add 10.0.1.10/24 dev eth0
ip link set eth0 up
ip route add default via 10.0.1.1
```

### Aluno2

```bash
ip addr add 10.0.1.11/24 dev eth0
ip link set eth0 up
ip route add default via 10.0.1.1
```

---

### Testes — Mesma VLAN

```bash
# Admin1 → UbuntuDesktop (VLAN 1000): deve funcionar
ping -c 3 10.0.0.11

# Aluno1 → Aluno2 (VLAN 2000): deve funcionar
ping -c 3 10.0.1.11
```

### Testes — Gateway

```bash
# Admin1 → Gateway Admin (VLAN 1000)
ping -c 3 10.0.0.1

# Aluno1 → Gateway Alunos (VLAN 2000)
ping -c 3 10.0.1.1
```

> **Atenção:** o ping de Aluno1 ao gateway (`10.0.1.1`) **vai falhar**. Por padrão, a interface OPT1 não possui nenhuma regra de firewall no pfSense, bloqueando todo o tráfego originado na VLAN 2000 — incluindo pings ao próprio gateway. Isso será corrigido na Parte 5.

### Testes — Entre VLANs

```bash
# Admin1 → Aluno1 (VLAN 1000 → VLAN 2000)
ping -c 3 10.0.1.10
```

> **Resultado esperado:** este teste também vai falhar enquanto não houver regras no firewall para OPT1 (Parte 5).

### Testes — Internet

```bash
# De qualquer host
ping -c 3 8.8.8.8
```

> Os hosts da VLAN 2000 não conseguirão acessar a Internet até que as regras de firewall sejam configuradas na Parte 5.

---

### Perguntas

* Os hosts da VLAN 1000 conseguem se comunicar com os da VLAN 2000? Por quê?
* Quem decide se o tráfego entre VLANs é permitido?
* Qual é o caminho que um pacote de Admin1 até Aluno1 percorre?

---

## Parte 5 — Regras de firewall no pfSense

### Objetivo

Configurar regras de firewall para permitir tráfego de saída (Internet) e definir a política de comunicação entre VLANs.

---

### Acessar a interface web do pfSense

As configurações a seguir são feitas pela interface web. No **UbuntuDesktop**, abra o **Firefox** e acesse:

```
http://10.0.0.1
```

Credenciais:
* **Usuário:** `admin`
* **Senha:** `15lab66infra`

---

### Passo 1 — Permitir tráfego de saída na VLAN 1000 (LAN)

A interface LAN (VLAN 1000) já possui uma regra padrão que permite todo o tráfego. Caso não esteja presente, adicione:

1. Vá em **Firewall > Rules > LAN**
2. Clique em **+ Add** (seta para cima — adicionar no topo)
3. Configure:
   * **Action:** Pass
   * **Protocol:** Any
   * **Source:** LAN net
   * **Destination:** Any
4. **Save** e **Apply Changes**

---

### Passo 2 — Adicionar regra para a VLAN 2000 (OPT1)

Por padrão, interfaces OPT no pfSense não têm nenhuma regra de firewall — todo o tráfego originado na VLAN 2000 é bloqueado, incluindo pings ao próprio gateway. É necessário adicionar uma regra explicitamente.

1. No **UbuntuDesktop**, acesse `http://10.0.0.1` com Firefox (usuário `admin`, senha `15lab66infra`)
2. Vá em **Firewall > Rules > OPT1**
3. Clique em **+ Add** (seta para cima — adicionar no topo)
4. Configure:
   * **Action:** Pass
   * **Interface:** OPT1
   * **Protocol:** Any
   * **Source:** OPT1 net
   * **Destination:** Any
5. **Save** e **Apply Changes**

Após aplicar a regra, os hosts da VLAN 2000 poderão alcançar o gateway, a Internet e (dependendo das regras futuras) a VLAN 1000.

---

### Passo 3 — Configurar servidores DNS no DHCP

O servidor DHCP foi habilitado pelo console sem incluir servidores DNS. Sem essa configuração, os hosts que receberem IP via DHCP não conseguirão resolver nomes de domínio. Configure os servidores DNS em cada interface pelo pfSense.

#### LAN (VLAN 1000)

1. Vá em **Services > DHCP Server > LAN**
2. Localize o campo **DNS Servers**
3. Preencha:
   * **DNS Server 1:** `8.8.8.8`
   * **DNS Server 2:** `1.1.1.1`
4. Clique em **Save**

#### OPT1 (VLAN 2000)

1. Vá em **Services > DHCP Server > OPT1**
2. Localize o campo **DNS Servers**
3. Preencha:
   * **DNS Server 1:** `8.8.8.8`
   * **DNS Server 2:** `1.1.1.1`
4. Clique em **Save**

---

### Testes após configurar as regras

De cada host, teste:

```bash
# Internet
ping -c 3 8.8.8.8

# DNS (se configurado)
ping -c 3 google.com

# Entre VLANs
# Admin1 → Aluno1
ping -c 3 10.0.1.10
```

---

### Perguntas

* Agora os hosts conseguem acessar a Internet?
* A comunicação entre VLANs está funcionando? Por quê?
* As regras que criamos são permissivas demais? Que riscos isso traz?

---

## Parte 6 — DHCP no pfSense

### Objetivo

Verificar a distribuição automática de endereços IP nas duas VLANs. O servidor DHCP já foi habilitado na Parte 3 (Passo 3) diretamente pelo console, com as faixas `10.0.0.100–10.0.0.200` (VLAN 1000) e `10.0.1.100–10.0.1.200` (VLAN 2000).

---

### Passo 1 — Testar nos hosts

#### Containers ubuntu-net (Admin1, Aluno1, Aluno2)

O container `ubuntu-net` não possui cliente DHCP por padrão. Antes de instalá-lo, configure o DNS temporariamente para que o `apt` consiga resolver os repositórios:

```bash
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
```

Instale o cliente DHCP:

```bash
apt update && apt install -y isc-dhcp-client
```

Remova a configuração manual e solicite IP via DHCP:

```bash
# Limpar IP manual
ip addr flush dev eth0
ip link set eth0 up

# Solicitar IP via DHCP
dhclient eth0
```

Verifique o IP recebido:

```bash
ip addr show eth0
ip route
```

#### UbuntuDesktop

O NetworkManager já gerencia DHCP automaticamente. Basta alterar o método de conexão de **Manual** para **Automático (DHCP)**:

```bash
nmcli con mod "Wired connection 1" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
nmcli con up "Wired connection 1"
```

Ou pela interface gráfica: **Configurações de Rede → engrenagem → IPv4 → Automático (DHCP) → Aplicar**.

Verifique o IP recebido:

```bash
ip addr show eth0
ip route
```

---

### Verificação

| Host | VLAN | IP esperado | Gateway esperado |
|------|------|-------------|------------------|
| Admin1 | 1000 | 10.0.0.100-200 | 10.0.0.1 |
| UbuntuDesktop | 1000 | 10.0.0.100-200 | 10.0.0.1 |
| Aluno1 | 2000 | 10.0.1.100-200 | 10.0.1.1 |
| Aluno2 | 2000 | 10.0.1.100-200 | 10.0.1.1 |

---

### Testes completos

```bash
# Conectividade local
ping -c 3 10.0.0.1    # ou 10.0.1.1 conforme a VLAN

# Internet
ping -c 3 8.8.8.8

# Resolução DNS
ping -c 3 google.com
```

---

### Perguntas

* Como o pfSense sabe para qual host entregar qual faixa de IP?
* O que acontece se um host da VLAN 2000 solicitar DHCP? Ele recebe IP da faixa 10.0.0.x ou 10.0.1.x?
* Qual a vantagem de usar DHCP em vez de IP manual?

---

## Parte 7 — Observando o tráfego

### Objetivo

Usar tcpdump para observar o tráfego tagueado no trunk e o tráfego sem tag nas portas access.

---

### No OVS — Porta trunk (eth1)

```bash
tcpdump -i eth1 -e -n
```

A flag `-e` mostra os cabeçalhos Ethernet, incluindo as **tags 802.1Q**. Você verá algo como:

```
... vlan 1000, p 0, ethertype IPv4, 10.0.0.10 > 10.0.0.1: ICMP echo request ...
... vlan 2000, p 0, ethertype IPv4, 10.0.1.10 > 10.0.1.1: ICMP echo request ...
```

---

### No OVS — Porta access (eth2)

```bash
tcpdump -i eth2 -e -n
```

Aqui o tráfego **não terá** tag VLAN, pois portas access removem a tag antes de entregar ao host.

---

### Experimento

1. Abra tcpdump na porta trunk (`eth1`) do OVS
2. Em outro terminal, faça ping de Admin1 para o gateway
3. Observe as tags VLAN nos pacotes
4. Repita com ping de Aluno1 para o gateway
5. Compare as tags

---

### Perguntas

* Qual a diferença que você observou entre o tráfego na porta trunk e na porta access?
* Como o switch OVS sabe qual tag adicionar ao quadro de um host?
* Se você capturar tráfego na interface `eth0` do Admin1, verá tags VLAN?

---

## Parte 8 — Desafio final

### Cenário

> *"A equipe de segurança determinou que a rede de Alunos (VLAN 2000) deve ter acesso apenas à Internet (HTTP e HTTPS), sem poder acessar a rede de Administração. A rede de Administração deve ter acesso irrestrito."*

### Requisitos

1. Alunos podem acessar a Internet (portas 80 e 443)
2. Alunos podem fazer consultas DNS (porta 53)
3. Alunos **não** podem acessar a rede 10.0.0.0/24 (Administração)
4. Alunos **não** podem usar ping para a Internet
5. Administração mantém acesso irrestrito

### Dicas

* Regras de firewall no pfSense são avaliadas **de cima para baixo**
* Uma regra de bloqueio deve vir **antes** de uma regra de permissão geral
* Configure as regras em **Firewall > Rules > OPT1**

### Validação

Teste a partir de Aluno1:

```bash
# Deve FUNCIONAR
curl -k https://google.com
curl http://example.com

# Deve FALHAR
ping -c 3 10.0.0.10
ping -c 3 8.8.8.8
```

Teste a partir de Admin1:

```bash
# Tudo deve FUNCIONAR
ping -c 3 8.8.8.8
ping -c 3 10.0.1.10
curl -k https://google.com
```

---

## Entregável

Cada equipe deve entregar:

* Print da topologia montada no GNS3
* Print da configuração do OVS (`ovs-vsctl show`)
* Print das VLANs criadas no pfSense
* Print das regras de firewall configuradas
* Prints dos testes de ping e curl (funcionando e bloqueados)
* Captura do tcpdump mostrando tags VLAN no trunk
* Respostas às perguntas de cada parte

---

## Conceitos abordados

| Conceito | Onde foi abordado |
|----------|-------------------|
| Porta trunk (802.1Q) | Partes 2, 7 |
| Porta access | Parte 2 |
| Router-on-a-stick | Partes 1, 3 |
| VLANs no pfSense | Parte 3 |
| Firewall (regras) | Partes 5, 8 |
| NAT | Partes 1, 5 |
| DHCP por VLAN | Parte 6 |
| Análise de tráfego 802.1Q | Parte 7 |

---

## Comandos úteis para revisão

```bash
# OVS — ver configuração completa
ovs-vsctl show

# OVS — ver tabela MAC
ovs-appctl fdb/show br0

# OVS — ver VLANs de uma porta
ovs-vsctl get port eth1 trunks
ovs-vsctl get port eth2 tag

# Hosts — ver IP e rotas
ip addr show eth0
ip route

# Hosts — solicitar DHCP
dhclient eth0

# Hosts — capturar tráfego com tags
tcpdump -i eth1 -e -n

# Hosts — testar web
curl -k https://google.com
```

---

## Próximos passos

Em aulas futuras:

* Múltiplos switches com trunk entre eles
* VPN entre sites
* Monitoramento de tráfego com Snort/Suricata no pfSense
* QoS e limitação de banda por VLAN
