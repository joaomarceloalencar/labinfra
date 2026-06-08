# 🧪 Atividade 11 — Laboratório de Infraestrutura de Redes — Roteamento Dinâmico com OSPF

## Objetivo

Este laboratório apresenta o **roteamento dinâmico** usando o protocolo **OSPF (Open Shortest Path First)** em uma topologia em anel com três roteadores MikroTik CHR. O foco é compreender como o OSPF descobre rotas automaticamente, reage a falhas de enlace e seleciona caminhos com base em custo.

Ao final, o aluno será capaz de:

* Explicar como o OSPF descobre vizinhos e distribui informações de topologia
* Configurar OSPF no MikroTik RouterOS v7
* Verificar adjacências, a base de dados de estado de enlace (LSDB) e as rotas instaladas
* Observar a convergência automática após falha de enlace
* Manipular o custo OSPF para influenciar a seleção de rotas
* Medir largura de banda com iPerf antes e depois de uma falha

---

## Duração estimada

Aproximadamente **3h**

---

## Pré-requisitos

* Ter concluído a Atividade 10 (configuração básica do MikroTik: IP, DHCP, NAT)
* Templates disponíveis no GNS3:
  * Container: `ubuntu-net` (insightlab/ubuntu-net:1.0)
  * Switch: Open vSwitch (insightlab/ovs:1.1)
  * Roteador: **MikroTikCHR7.22.1-1** (QEMU)
  * Cloud: NAT

---

## Teoria — Roteamento Dinâmico e OSPF

### Limitações do Roteamento Estático

Nas atividades anteriores, usamos **rotas estáticas**: o administrador configurou manualmente cada rota em cada roteador. Isso funciona bem para redes pequenas, mas apresenta problemas sérios conforme a rede cresce:

* **Escalabilidade precária:** em uma rede com dezenas de roteadores, manter tabelas de rotas manualmente é inviável.
* **Ausência de resiliência:** se um enlace falha, os pacotes continuam sendo enviados pelo caminho inoperante até que o administrador intervenha.
* **Alto custo operacional:** qualquer mudança na topologia exige reconfiguração manual em vários dispositivos.

Os **protocolos de roteamento dinâmico** resolvem esses problemas: os roteadores trocam informações entre si automaticamente e atualizam suas tabelas de rotas sem intervenção humana.

### Famílias de Protocolos de Roteamento Dinâmico

| Família | Abordagem | Exemplos |
|---------|-----------|---------|
| **Vetor de distância** | Cada roteador anuncia sua tabela de rotas aos vizinhos; os vizinhos acumulam saltos | RIP, EIGRP |
| **Estado de enlace** | Cada roteador anuncia o estado de seus próprios enlaces; todos calculam o grafo completo | **OSPF**, IS-IS |

O OSPF é o protocolo de **estado de enlace** mais utilizado em redes corporativas e de provedores.

### OSPF: Open Shortest Path First

#### Como o OSPF funciona — três etapas

**Etapa 1 — Descoberta de vizinhos (Hello packets)**

Roteadores OSPF enviam pacotes **Hello** periodicamente por todas as interfaces habilitadas para OSPF. Quando dois roteadores trocam Hellos com parâmetros compatíveis (mesma área, mesma sub-rede, mesmo intervalo de Hello), eles estabelecem uma **adjacência** — uma relação de vizinhança confirmada.

```
R1 ──────── Hello ──────► R2
R1 ◄──────── Hello ──────  R2
           (adjacência formada)
```

**Etapa 2 — Inundação de informações de topologia (LSAs)**

Cada roteador gera um **LSA (Link State Advertisement)** descrevendo seus próprios enlaces: quais vizinhos possui e o custo de cada enlace. Os LSAs são **inundados** (*flooded*) para todos os roteadores da área, que os armazenam na **LSDB (Link State Database)** — uma representação completa do grafo da rede.

> Todos os roteadores de uma mesma área OSPF possuem **a mesma LSDB**. Esta é a característica fundamental que distingue protocolos de estado de enlace dos de vetor de distância: cada roteador enxerga a topologia completa, não apenas o que seus vizinhos anunciam.

**Etapa 3 — Cálculo de rotas (Algoritmo de Dijkstra)**

Com a LSDB completa, cada roteador executa o **algoritmo de Dijkstra (SPF — Shortest Path First)** localmente. O algoritmo encontra, para cada destino, o caminho de menor custo total. O resultado é instalado na tabela de roteamento IP.

```
LSDB (grafo completo)  ─►  Algoritmo SPF  ─►  Tabela de Rotas
```

#### Custo OSPF

O custo de uma interface OSPF representa o "esforço" de enviar tráfego por ela. O caminho escolhido é sempre o de **menor custo total** (soma dos custos de todas as interfaces no caminho). A fórmula padrão é:

```
Custo = Largura de banda de referência / Largura de banda da interface
```

A largura de banda de referência padrão no MikroTik é **100 Mbps**. Portanto:

| Interface | Velocidade | Custo padrão |
|-----------|-----------|--------------|
| Fast Ethernet | 100 Mbps | 1 |
| Gigabit Ethernet | 1000 Mbps | 1 (mínimo) |
| Link serial 64 kbps | 0,064 Mbps | ~1562 |

Em ambientes virtualizados como o GNS3, todas as interfaces costumam aparecer como Gigabit — o custo calculado seria 1 para todas. Neste laboratório manipularemos os custos **manualmente** para demonstrar a seleção de rotas com clareza.

#### Convergência

Quando um enlace falha, o roteador adjacente percebe pela ausência de Hellos. Após o **Dead Interval** (por padrão, 4× o Hello Interval = 40 segundos), o roteador considera o vizinho inoperante e:

1. Gera um novo LSA informando que aquele enlace está morto
2. Inunda o LSA para toda a área
3. Todos os roteadores recalculam o SPF
4. As tabelas de rotas são atualizadas com o novo caminho

O tempo total de convergência com configurações padrão costuma ser de **30 a 60 segundos**. Com ajuste dos timers (Hello Interval, Dead Interval e atraso do SPF), redes modernas convergem em menos de 1 segundo.

#### O que o OSPF NÃO faz: roteamento por congestionamento

É importante entender o que o OSPF **não é**: ele não detecta congestionamento em tempo real. Se um enlace está congestionado mas continua ativo (sem falha), o OSPF continua enviando tráfego por ele — afinal, seu custo configurado não mudou.

O OSPF oferece **resiliência a falhas** e **controle de caminho por custo configurado**. Para roteamento sensível a carga em tempo real, são necessários recursos como RSVP-TE, MPLS Traffic Engineering ou tecnologias SDN.

O que podemos demonstrar neste laboratório com iPerf é o **ECMP (Equal-Cost Multi-Path)**: quando dois caminhos têm custo idêntico, o OSPF instala ambos na tabela de rotas e o roteador distribui os fluxos entre eles.

#### Áreas OSPF

Em redes grandes, o OSPF é dividido em **áreas** para limitar o escopo das inundações de LSAs. Toda rede OSPF possui pelo menos a **Área 0 (backbone)**. Neste laboratório usaremos apenas a Área 0, pois nossa topologia é pequena e simples.

### OSPF no MikroTik RouterOS v7

O RouterOS v7 organiza a configuração OSPF em três objetos hierárquicos:

```
/routing ospf instance       ← processo OSPF (um por roteador em topologias simples)
    └─ /routing ospf area    ← área OSPF (usaremos só backbone = 0.0.0.0)
           └─ /routing ospf interface-template  ← quais interfaces participam e com qual custo
```

Comandos de verificação:

| Comando | O que mostra |
|---------|-------------|
| `/routing ospf neighbor print` | Adjacências OSPF formadas |
| `/routing ospf lsa print area=backbone` | LSAs na base de dados (LSDB) |
| `/ip route print where protocol=ospf` | Rotas instaladas pelo OSPF |
| `/routing ospf interface-template print` | Interfaces e custos configurados |

---

## Topologia

### Diagrama

```
                   [ NAT do GNS3 ]
                         |
                       ether1
                       [ R1 ]
          ether2                  ether3
    10.0.12.1/30            10.0.13.1/30
          |                        |
    10.0.12.2/30            10.0.13.2/30
       ether1                   ether1
       [ R2 ] ─── 10.0.23.0/30 ─── [ R3 ]
       ether2                   ether2
   10.0.23.1/30              10.0.23.2/30

Cada roteador tem uma LAN própria:
  R1 ether4 ─► [OVS-R1] ─► PC-LAN1   (192.168.1.0/24)
  R2 ether3 ─► [OVS-R2] ─► PC-LAN2   (192.168.2.0/24)
  R3 ether3 ─► [OVS-R3] ─► PC-LAN3   (192.168.3.0/24)
```

A topologia em **anel** (R1–R2–R3–R1) é essencial para este laboratório: ela garante que sempre existe um caminho alternativo para qualquer par de roteadores quando um enlace falha.

### Tabela de endereçamento

| Dispositivo | Interface | Endereço IP | Propósito |
|-------------|-----------|-------------|-----------|
| R1 | ether1 | DHCP via NAT | Acesso à Internet |
| R1 | ether2 | 10.0.12.1/30 | Enlace R1–R2 |
| R1 | ether3 | 10.0.13.1/30 | Enlace R1–R3 |
| R1 | ether4 | 192.168.1.1/24 | Gateway LAN1 |
| R2 | ether1 | 10.0.12.2/30 | Enlace R2–R1 |
| R2 | ether2 | 10.0.23.1/30 | Enlace R2–R3 |
| R2 | ether3 | 192.168.2.1/24 | Gateway LAN2 |
| R3 | ether1 | 10.0.13.2/30 | Enlace R3–R1 |
| R3 | ether2 | 10.0.23.2/30 | Enlace R3–R2 |
| R3 | ether3 | 192.168.3.1/24 | Gateway LAN3 |
| PC-LAN1 | eth0 | 192.168.1.100–200 | Host LAN1 (DHCP) |
| PC-LAN2 | eth0 | 192.168.2.100–200 | Host LAN2 (DHCP) |
| PC-LAN3 | eth0 | 192.168.3.100–200 | Host LAN3 (DHCP) |

> **Links /30:** usamos redes `/30` (apenas 2 hosts) nos enlaces ponto-a-ponto entre roteadores. Isso é uma boa prática: evita desperdício de endereços em links que possuem exatamente dois roteadores.

---

## Pré-configuração — Montar topologia e configurar IP

Antes de habilitar o OSPF, configure os endereços IP em todos os roteadores. Esta etapa reproduz o que você aprendeu na Atividade 10, aplicado a três roteadores.

### Montar a topologia no GNS3

1. Adicione ao projeto:
   * 1 **NAT** (cloud)
   * 3 **MikroTikCHR7.22.1-1** (QEMU): renomeie para **R1**, **R2** e **R3**
   * 3 **Open vSwitch**: renomeie para **OVS-R1**, **OVS-R2** e **OVS-R3**
   * 3 containers **ubuntu-net**: renomeie para **PC-LAN1**, **PC-LAN2** e **PC-LAN3**

2. Conecte os cabos:

   | De | Porta | Para | Porta |
   |----|-------|------|-------|
   | NAT | — | R1 | e0 (ether1) |
   | R1 | e1 (ether2) | R2 | e0 (ether1) |
   | R2 | e1 (ether2) | R3 | e1 (ether2) |
   | R3 | e0 (ether1) | R1 | e2 (ether3) |
   | R1 | e3 (ether4) | OVS-R1 | eth1 |
   | R2 | e2 (ether3) | OVS-R2 | eth1 |
   | R3 | e2 (ether3) | OVS-R3 | eth1 |
   | PC-LAN1 | eth0 | OVS-R1 | eth2 |
   | PC-LAN2 | eth0 | OVS-R2 | eth2 |
   | PC-LAN3 | eth0 | OVS-R3 | eth2 |

3. Inicie todos os dispositivos.

### Configurar R1

```
/system identity set name=R1

# WAN: DHCP via NAT
/ip dhcp-client add interface=ether1 disabled=no

# Enlace para R2
/ip address add address=10.0.12.1/30 interface=ether2

# Enlace para R3
/ip address add address=10.0.13.1/30 interface=ether3

# LAN1
/ip address add address=192.168.1.1/24 interface=ether4

# Pool e servidor DHCP para LAN1
/ip pool add name=lan1-pool ranges=192.168.1.100-192.168.1.200
/ip dhcp-server add name=lan1-dhcp interface=ether4 address-pool=lan1-pool disabled=no
/ip dhcp-server network add address=192.168.1.0/24 gateway=192.168.1.1 dns-server=8.8.8.8

# NAT para saída à Internet
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
```

Verifique:

```
/ip address print
/ip dhcp-client print
```

### Configurar R2

```
/system identity set name=R2

# Enlace para R1
/ip address add address=10.0.12.2/30 interface=ether1

# Enlace para R3
/ip address add address=10.0.23.1/30 interface=ether2

# LAN2
/ip address add address=192.168.2.1/24 interface=ether3

# Pool e servidor DHCP para LAN2
/ip pool add name=lan2-pool ranges=192.168.2.100-192.168.2.200
/ip dhcp-server add name=lan2-dhcp interface=ether3 address-pool=lan2-pool disabled=no
/ip dhcp-server network add address=192.168.2.0/24 gateway=192.168.2.1 dns-server=8.8.8.8
```

Verifique:

```
/ip address print
```

### Configurar R3

```
/system identity set name=R3

# Enlace para R1
/ip address add address=10.0.13.2/30 interface=ether1

# Enlace para R2
/ip address add address=10.0.23.2/30 interface=ether2

# LAN3
/ip address add address=192.168.3.1/24 interface=ether3

# Pool e servidor DHCP para LAN3
/ip pool add name=lan3-pool ranges=192.168.3.100-192.168.3.200
/ip dhcp-server add name=lan3-dhcp interface=ether3 address-pool=lan3-pool disabled=no
/ip dhcp-server network add address=192.168.3.0/24 gateway=192.168.3.1 dns-server=8.8.8.8
```

### Configurar os hosts

Em cada PC (PC-LAN1, PC-LAN2, PC-LAN3):

```bash
dhclient eth0
ip addr show eth0
ip route
```

Verifique que cada host recebeu IP na faixa correta e tem gateway configurado.

### Verificação de conectividade local (antes do OSPF)

Neste momento, os roteadores conseguem pingar apenas os vizinhos diretamente conectados:

```
# No R1 — pings que devem funcionar
ping 10.0.12.2    ← R2 via enlace direto
ping 10.0.13.2    ← R3 via enlace direto
ping 192.168.1.1  ← própria LAN1

# No R1 — pings que DEVEM FALHAR (sem rota)
ping 192.168.2.1  ← LAN2 de R2 (ainda não há rota)
ping 192.168.3.1  ← LAN3 de R3 (ainda não há rota)
```

Este é o comportamento esperado. O OSPF resolverá isso nas próximas etapas.

---

## Parte 1 — Configuração OSPF

### Objetivo

Habilitar OSPF nos três roteadores e verificar que as redes de todas as LANs são aprendidas automaticamente.

---

### Configurar OSPF no R1

O OSPF no RouterOS v7 requer três objetos: **instância**, **área** e **interface-template**.

#### Passo 1 — Criar a instância OSPF

```
/routing ospf instance add name=default version=2
```

A instância é o processo OSPF. O parâmetro `version=2` especifica OSPFv2 (IPv4). Usamos `name=default` por convenção.

#### Passo 2 — Criar a Área 0 (backbone)

```
/routing ospf area add name=backbone area-id=0.0.0.0 instance=default
```

A Área 0 é obrigatória em toda rede OSPF. O `area-id=0.0.0.0` é o identificador da área backbone.

#### Passo 3 — Adicionar interfaces ao OSPF

Os **interface-templates** definem quais interfaces participam do OSPF e de que forma:

```
# Enlace ponto-a-ponto com R2
/routing ospf interface-template add interfaces=ether2 area=backbone type=ptp

# Enlace ponto-a-ponto com R3
/routing ospf interface-template add interfaces=ether3 area=backbone type=ptp

# LAN1 (interface broadcast)
/routing ospf interface-template add interfaces=ether4 area=backbone type=broadcast
```

> **Por que `type=ptp` nos enlaces entre roteadores?** Em enlaces ponto-a-ponto, não há necessidade de eleger um roteador designado (DR) nem um de backup (BDR) — há exatamente dois roteadores. O tipo `ptp` elimina esse processo, acelerando a formação de adjacências. Em interfaces de rede (LAN), o tipo `broadcast` é o correto.

#### Passo 4 — Redistribuir a rota padrão (acesso à Internet)

Para que R2 e R3 (e suas LANs) consigam acessar a Internet via R1, R1 deve anunciar uma rota padrão pelo OSPF:

```
/routing ospf instance set default originate-default=always
```

Isso instrui R1 a anunciar `0.0.0.0/0` via OSPF, mesmo que essa rota seja externa ao OSPF (veio via DHCP da WAN).

#### Verificação no R1

```
/routing ospf instance print
/routing ospf area print
/routing ospf interface-template print
```

---

### Configurar OSPF no R2

```
/routing ospf instance add name=default version=2
/routing ospf area add name=backbone area-id=0.0.0.0 instance=default

# Enlace ponto-a-ponto com R1
/routing ospf interface-template add interfaces=ether1 area=backbone type=ptp

# Enlace ponto-a-ponto com R3
/routing ospf interface-template add interfaces=ether2 area=backbone type=ptp

# LAN2
/routing ospf interface-template add interfaces=ether3 area=backbone type=broadcast
```

---

### Configurar OSPF no R3

```
/routing ospf instance add name=default version=2
/routing ospf area add name=backbone area-id=0.0.0.0 instance=default

# Enlace ponto-a-ponto com R1
/routing ospf interface-template add interfaces=ether1 area=backbone type=ptp

# Enlace ponto-a-ponto com R2
/routing ospf interface-template add interfaces=ether2 area=backbone type=ptp

# LAN3
/routing ospf interface-template add interfaces=ether3 area=backbone type=broadcast
```

---

## Parte 2 — Verificação do OSPF

### Verificar adjacências

Após alguns segundos, execute em cada roteador:

```
/routing ospf neighbor print
```

Saída esperada no R1:

```
Flags: V - virtual
 #   INSTANCE  AREA      ADDRESS      ROUTER-ID   STATE    PRIORITY  DR          BDR
 0   default   backbone  10.0.12.2    10.0.12.2   Full/PtP 1
 1   default   backbone  10.0.13.2    10.0.13.2   Full/PtP 1
```

O estado **Full** indica que a adjacência está completamente estabelecida e a LSDB foi sincronizada. Em enlaces ponto-a-ponto (PtP), não há eleição de DR/BDR — por isso aparece `Full/PtP`.

> Se o estado aparecer como `2-Way` ou `ExStart` e não progredir, verifique se os dois lados do enlace têm a mesma configuração de área e se os cabos estão conectados corretamente no GNS3.

### Verificar a base de dados OSPF (LSDB)

```
/routing ospf lsa print area=backbone
```

Você verá LSAs de tipo `router` — um para cada roteador na área. Cada LSA descreve os enlaces daquele roteador e seus custos. Todos os roteadores devem ter **o mesmo conjunto de LSAs**, confirmando que a LSDB está sincronizada.

### Verificar as rotas instaladas pelo OSPF

```
/ip route print where protocol=ospf
```

Saída esperada no R1 (após convergência total):

```
 #    DST-ADDRESS      GATEWAY       DISTANCE  PROTOCOL
 ...  192.168.2.0/24  10.0.12.2     110       ospf    ← LAN2 via R2
 ...  192.168.3.0/24  10.0.13.2     110       ospf    ← LAN3 via R3
 ...  10.0.23.0/30    10.0.12.2     110       ospf    ← enlace R2-R3 via R2
```

> A distância administrativa `110` é o valor padrão do OSPF no MikroTik. Rotas com distância menor têm preferência — rotas diretamente conectadas (distância 0) sempre prevalecem sobre rotas OSPF.

### Verificar conectividade entre LANs

De PC-LAN1, pinguie os hosts das outras LANs:

```bash
# LAN2
ping -c 3 192.168.2.1      ← gateway de R2

# LAN3
ping -c 3 192.168.3.1      ← gateway de R3
```

Ambos devem funcionar. Se PC-LAN2 e PC-LAN3 já executaram `dhclient eth0`, pinguie diretamente:

```bash
ping -c 3 <IP do PC-LAN2>
ping -c 3 <IP do PC-LAN3>
```

### Verificar acesso à Internet em R2 e R3

Graças à rota padrão redistribuída por R1, os demais roteadores já têm saída para Internet:

```
# No R2
ping 8.8.8.8

# No R3
ping 8.8.8.8
```

### Visualizar o caminho com traceroute

O traceroute revela por quais roteadores o tráfego passa. Execute no console do **R1**:

```
/tool traceroute 192.168.2.1
```

Saída esperada:

```
  # ADDRESS     LOSS  SENT  LAST  AVG  BEST  WORST  STD-DEV
  1 10.0.12.2   0%    3     1ms   1ms  1ms   2ms    0ms
  2 192.168.2.1 0%    3     1ms   1ms  1ms   2ms    0ms
```

O tráfego vai de R1 diretamente para R2 (via enlace R1–R2), que é o caminho mais curto.

Para alcançar LAN3:

```
/tool traceroute 192.168.3.1
```

Saída esperada:

```
  1 10.0.13.2   0%    3     1ms   1ms  1ms   2ms    0ms
  2 192.168.3.1 0%    3     1ms   1ms  1ms   2ms    0ms
```

O tráfego vai de R1 para R3 diretamente (via enlace R1–R3).

---

### Perguntas

* Quantos LSAs aparecem na LSDB de R1? O que cada um representa?
* Por que o estado da adjacência é `Full/PtP` e não `Full/DR`?
* Qual a diferença entre `distance=110` (OSPF) e `distance=0` (diretamente conectado)?
* A rota para `192.168.2.0/24` no R1 usa `10.0.12.2` como gateway. Por quê não usa o IP de R3?

---

## Parte 3 — Falha de Enlace e Convergência Automática

### Objetivo

Simular a falha do enlace R1–R2 e observar o OSPF reconverger automaticamente, redirecionando o tráfego pelo caminho alternativo R1→R3→R2.

---

### Preparação: ping contínuo

Abra o terminal de **PC-LAN1** e inicie um ping contínuo para o **gateway de LAN2**:

```bash
ping -i 0.5 192.168.2.1
```

O parâmetro `-i 0.5` envia um ping a cada 500 ms, permitindo observar a interrupção e retomada com boa resolução temporal.

Deixe este ping rodando. Abra um segundo terminal (ou uma segunda sessão no mesmo host) e execute:

```bash
ping -i 0.5 192.168.3.1
```

Mantenha os dois pings visíveis simultaneamente.

### Verificar o caminho atual

No console de **R1**, antes de simular a falha:

```
/tool traceroute 192.168.2.1
```

Anote o caminho (deve passar por `10.0.12.2`).

### Simular a falha: desabilitar o enlace R1–R2

No console de **R1**, desabilite a interface `ether2`:

```
/interface disable ether2
```

Observe o ping para LAN2: haverá uma série de timeouts enquanto o OSPF detecta a falha e reconverge. O tempo de interrupção depende do **Dead Interval** (padrão: 40 segundos).

> O ping para LAN3 deve continuar funcionando sem interrupção, pois o enlace R1–R3 não foi afetado.

### Aguardar convergência e verificar novo caminho

Após o OSPF reconverger (os pings para LAN2 voltam a responder), execute no R1:

```
/tool traceroute 192.168.2.1
```

O novo caminho deve ser:

```
  1 10.0.13.2   0%   3   ...    ← R3, via enlace R1–R3
  2 10.0.23.2   0%   3   ...    ← R3 entrega para R2 via enlace R3–R2
  3 192.168.2.1 0%   3   ...    ← LAN2 de R2
```

O OSPF roteou automaticamente pelo caminho alternativo sem nenhuma intervenção manual.

Verifique também as rotas:

```
/ip route print where protocol=ospf
```

A rota para `192.168.2.0/24` agora aponta para `10.0.13.2` (R3) em vez de `10.0.12.2` (R2 diretamente).

### Restaurar o enlace

Reabilite a interface:

```
/interface enable ether2
```

Aguarde a convergência e observe o traceroute voltar ao caminho direto R1→R2.

---

### Ajustar os timers para convergência mais rápida (opcional)

O Dead Interval padrão de 40 segundos pode ser reduzido para observar convergência mais rápida nos experimentos. Configure em todos os interface-templates dos enlaces ponto-a-ponto:

```
# Em R1 — interface para R2
/routing ospf interface-template set [find interfaces=ether2] hello-interval=5s dead-interval=20s

# Em R2 — interface para R1
/routing ospf interface-template set [find interfaces=ether1] hello-interval=5s dead-interval=20s
```

Com `dead-interval=20s`, a convergência após falha ocorrerá em cerca de **20 segundos** em vez de 40.

> Para redes de produção com demanda por alta disponibilidade, timers ainda menores (hello=1s, dead=4s) são comuns, mas exigem mais CPU dos roteadores.

---

### Perguntas

* Quantos pings foram perdidos durante a convergência? Isso é aceitável em uma rede de produção?
* Por que o ping para LAN3 não foi interrompido quando desabilitamos `ether2`?
* O que acontece na LSDB de R2 quando o enlace R1–R2 cai? Execute `/routing ospf lsa print area=backbone` em R2 antes e depois da falha.
* Qual seria o impacto de remover **dois** enlaces simultaneamente nesta topologia em anel?

---

## Parte 4 — Manipulação de Custo OSPF

### Objetivo

Demonstrar que o OSPF seleciona rotas pelo **menor custo total**. Ao aumentar o custo de um enlace, o OSPF escolhe automaticamente o caminho alternativo — mesmo que ele passe por mais saltos.

---

### Verificar custos atuais

Em R1:

```
/routing ospf interface-template print
```

Por padrão, o custo de todas as interfaces em ambientes virtualizados tende a ser **10** (RouterOS usa como mínimo). O custo total de R1 até LAN2:

* Via R1–R2 diretamente: custo `ether2_R1` + `ether3_R2` = 10 + 10 = **20**
* Via R1–R3–R2: custo `ether3_R1` + `ether2_R3` + `ether2_R2` = 10 + 10 + 10 = **30**

Por isso o OSPF prefere o caminho direto.

### Aumentar o custo do enlace R1–R2

Vamos definir custo 100 no enlace R1–R2 para forçar o OSPF a preferir o caminho via R3:

No **R1**:

```
/routing ospf interface-template set [find interfaces=ether2] cost=100
```

No **R2** (o lado oposto do mesmo enlace):

```
/routing ospf interface-template set [find interfaces=ether1] cost=100
```

> O custo OSPF é **assimétrico por enlace**: o custo que R1 anuncia é o custo de *R1 para R2*. O custo que R2 anuncia é o custo de *R2 para R1*. Para forçar caminhos simétricos, é boa prática definir o mesmo custo nos dois lados.

Aguarde alguns segundos para o OSPF recalcular.

### Verificar o novo caminho preferido

No R1:

```
/tool traceroute 192.168.2.1
```

O caminho agora deve passar por R3:

```
  1 10.0.13.2   0%   3   ...    ← R3 (via R1–R3, custo 10)
  2 10.0.23.2   0%   3   ...    ← R2 (via R3–R2, custo 10)
  3 192.168.2.1 0%   3   ...
```

Custo total via R3: 10 + 10 + 10 = **30**, menor que o custo 100 + 10 = **110** via enlace direto R1–R2.

Verifique também as rotas:

```
/ip route print where protocol=ospf
```

A rota para `192.168.2.0/24` agora aponta para `10.0.13.2` (R3).

### Restaurar os custos padrão

```
# No R1
/routing ospf interface-template set [find interfaces=ether2] cost=10

# No R2
/routing ospf interface-template set [find interfaces=ether1] cost=10
```

---

### Perguntas

* Se você aumentar o custo de R1–R3 também para 100, o que o OSPF escolhe? Teste.
* O que acontece se você colocar custo 100 nos dois sentidos do enlace R1–R2, mas custo 1 no enlace R1–R3 e custo 1 no R3–R2? Calcule os caminhos antes de testar.
* Como você usaria a manipulação de custo para fazer balanceamento de carga manual entre dois caminhos?

---

## Parte 5 — Medição de Desempenho com iPerf

### Objetivo

Usar o **iPerf3** para medir a largura de banda disponível entre hosts em LANs diferentes e observar o comportamento durante uma falha de enlace.

---

### Instalar o iPerf3

O iPerf3 não está pré-instalado nas imagens. Com acesso à Internet via R1 (configurado na pré-configuração), instale nos hosts que serão usados:

Em **PC-LAN1** e **PC-LAN2**:

```bash
apt-get update && apt-get install -y iperf3
```

> Se o host não tiver acesso à Internet, verifique se recebeu IP e DNS com `ip addr`, `ip route` e `ping 8.8.8.8`.

---

### Medir largura de banda entre LAN1 e LAN2

#### Iniciar o servidor em PC-LAN2

```bash
iperf3 -s
```

O servidor aguarda conexões na porta 5201 (padrão).

#### Executar o cliente em PC-LAN1

```bash
iperf3 -c <IP de PC-LAN2> -t 30 -i 2
```

Parâmetros:
* `-c <IP>` — endereço do servidor
* `-t 30` — duração do teste: 30 segundos
* `-i 2` — relatório a cada 2 segundos

Saída esperada (valores variam conforme o ambiente):

```
[ ID] Interval      Transfer     Bitrate
[  5] 0.00-2.00    sec  X MBytes  Y Mbits/sec
[  5] 2.00-4.00    sec  X MBytes  Y Mbits/sec
...
```

#### Monitorar o tráfego nos enlaces de R1

Enquanto o iPerf roda, abra o console de **R1** e execute:

```
/interface monitor-traffic ether2,ether3 interval=2
```

Você verá que o tráfego flui pelo enlace `ether2` (R1→R2) e `ether3` permanece quase ocioso — o OSPF escolheu o caminho direto.

Pressione `q` para sair do monitor.

---

### Observar failover durante transferência ativa

Esta é a demonstração mais impactante: o iPerf continuará transferindo dados mesmo com uma falha de enlace, usando automaticamente o caminho alternativo após a convergência OSPF.

1. Inicie novamente o servidor em PC-LAN2:

   ```bash
   iperf3 -s
   ```

2. Inicie o cliente em PC-LAN1 com teste longo:

   ```bash
   iperf3 -c <IP de PC-LAN2> -t 120 -i 2
   ```

3. Enquanto o teste está rodando, no console de **R1**, desabilite o enlace direto:

   ```
   /interface disable ether2
   ```

4. Observe no output do iPerf:
   * Haverá **intervalos com taxa zero** durante a convergência do OSPF
   * Após a convergência (~20–40 segundos), a transferência **retoma automaticamente** pelo caminho alternativo (R1→R3→R2)

5. Verifique no monitor de tráfego de R1 que agora o tráfego flui por `ether3`:

   ```
   /interface monitor-traffic ether2,ether3 interval=2
   ```

6. Reabilite o enlace:

   ```
   /interface enable ether2
   ```

---

### ECMP — Balanceamento de Carga com Caminhos de Custo Igual (Avançado)

Quando dois caminhos têm **exatamente o mesmo custo total**, o OSPF pode instalar ambos na tabela de rotas e o roteador distribui os fluxos entre eles — isso se chama **ECMP (Equal-Cost Multi-Path)**.

Para criar caminhos de custo igual entre R1 e LAN2:

```
Caminho 1: R1→R2 direto       = custo ether2_R1 + custo ether3_R2
Caminho 2: R1→R3→R2           = custo ether3_R1 + custo ether2_R3 + custo ether2_R2
```

Defina os custos para igualar os dois caminhos (exemplo: custo 20 em cada):

No **R1**:

```
/routing ospf interface-template set [find interfaces=ether2] cost=20
/routing ospf interface-template set [find interfaces=ether3] cost=10
```

No **R2**:

```
/routing ospf interface-template set [find interfaces=ether1] cost=20   ← custo R2→R1
/routing ospf interface-template set [find interfaces=ether2] cost=10   ← custo R2→R3
```

No **R3**:

```
/routing ospf interface-template set [find interfaces=ether1] cost=10   ← custo R3→R1
/routing ospf interface-template set [find interfaces=ether2] cost=10   ← custo R3→R2
```

Custo via direto: 20 (R1→R2) + 10 (LAN2) = 30 até a rede 192.168.2.0/24
Custo via R3: 10 (R1→R3) + 10 (R3→R2) + 10 (LAN2) = 30

Ative o ECMP na instância OSPF do R1:

```
/routing ospf instance set default ecmp=yes
```

Verifique se duas rotas aparecem para LAN2:

```
/ip route print where dst-address=192.168.2.0/24
```

Se duas entradas aparecerem com gateways diferentes (`10.0.12.2` e `10.0.13.2`), o ECMP está ativo.

> **Como observar a distribuição:** o MikroTik por padrão distribui fluxos por **destino** (per-destination hash). Para ver tráfego em ambos os enlaces simultaneamente, inicie dois fluxos iPerf para destinos diferentes (PC-LAN2 e PC-LAN3) e monitore com `/interface monitor-traffic ether2,ether3`.

---

### Perguntas

* Quantos segundos o iPerf ficou sem transmitir durante a falha de enlace? Isso corresponde ao tempo de convergência do OSPF?
* Com ECMP ativo, o que acontece se você desabilitar um dos dois enlaces? Teste.
* Por que o ECMP distribui por fluxo (não por pacote)? Qual seria o problema de distribuir por pacote?

---

## Entregável

* Print da topologia montada no GNS3 com os três roteadores e as LANs
* Print de `/routing ospf neighbor print` em cada roteador mostrando estado `Full`
* Print de `/ip route print where protocol=ospf` no R1 mostrando as rotas aprendidas
* Print do traceroute de R1 para LAN2 antes e depois de desabilitar `ether2`
* Print do output do iPerf mostrando a interrupção e retomada após falha
* Print do traceroute de R1 para LAN2 com custo manipulado, comprovando mudança de caminho
* Respostas às perguntas de cada parte

---

## Conceitos abordados

| Conceito | Onde foi abordado |
|----------|------------------|
| Roteamento estático vs. dinâmico | Teoria |
| Protocolo de estado de enlace | Teoria — OSPF |
| Hello packets e adjacências | Teoria — OSPF, Parte 1 |
| LSDB e inundação de LSAs | Teoria — OSPF, Parte 2 |
| Algoritmo de Dijkstra (SPF) | Teoria — OSPF |
| Custo OSPF | Teoria — OSPF, Parte 4 |
| Área OSPF (backbone) | Teoria — OSPF, Parte 1 |
| Redistribuição de rota padrão | Pré-configuração (R1) |
| Convergência após falha | Parte 3 |
| Dead Interval e ajuste de timers | Parte 3 |
| Manipulação de custo para seleção de rotas | Parte 4 |
| Medição de largura de banda com iPerf | Parte 5 |
| ECMP (Equal-Cost Multi-Path) | Parte 5 (avançado) |

---

## Referência rápida — OSPF no MikroTik RouterOS v7

```
# Instância OSPF
/routing ospf instance add name=default version=2
/routing ospf instance print
/routing ospf instance set default originate-default=always   ← redistribuir rota padrão
/routing ospf instance set default ecmp=yes                   ← habilitar ECMP

# Área
/routing ospf area add name=backbone area-id=0.0.0.0 instance=default
/routing ospf area print

# Interface templates
/routing ospf interface-template add interfaces=etherN area=backbone type=ptp
/routing ospf interface-template add interfaces=etherN area=backbone type=broadcast
/routing ospf interface-template set [find interfaces=etherN] cost=VALOR
/routing ospf interface-template set [find interfaces=etherN] hello-interval=5s dead-interval=20s
/routing ospf interface-template print

# Verificação
/routing ospf neighbor print
/routing ospf lsa print area=backbone
/ip route print where protocol=ospf

# Simular falha de enlace
/interface disable etherN
/interface enable etherN

# Traceroute
/tool traceroute X.X.X.X

# Monitor de tráfego em tempo real
/interface monitor-traffic ether2,ether3 interval=2
```

---

## Próximos passos

* Redistribuição de rotas entre OSPF e rotas estáticas
* OSPFv3 (para IPv6)
* BGP (Border Gateway Protocol) — o protocolo de roteamento da Internet
* VPN site-a-site entre dois R1s com roteamento OSPF interno
