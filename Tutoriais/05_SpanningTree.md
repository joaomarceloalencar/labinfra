# Laboratório 04 — Spanning Tree Protocol com Open vSwitch

## Objetivo

Este laboratório demonstra o problema de loops em redes L2 e como o Spanning Tree Protocol (STP) os resolve automaticamente.

Ao final, o aluno será capaz de:

* Entender por que loops Ethernet causam tempestades de broadcast
* Habilitar e monitorar STP no Open vSwitch
* Identificar a root bridge, as portas designadas e a porta bloqueada
* Comparar os tempos de convergência do STP clássico (802.1D) e do RSTP (802.1w)
* Controlar o comportamento do STP ajustando prioridades e custos de caminho

---

## Duração estimada

Aproximadamente **3h**

---

## Pré-requisitos

* Ter concluído o Laboratório 04
* Templates disponíveis no GNS3 (mesmos do Lab 04):
  * Container: `ubuntu-net` (insightlab/ubuntu-net:1.0)
  * Máquina virtual: `UbuntuDesktop` (QEMU)
  * Switch: Open vSwitch (insightlab/ovs:1.1)
  * Roteador/Firewall: pfSense (QEMU)
  * Cloud: NAT

---

## Conceitos importantes

### O problema dos loops em L2

Em redes Ethernet, quadros **não têm TTL** — diferente de pacotes IP, eles não são descartados automaticamente após um número de saltos. Quando existem dois caminhos L2 entre switches sem nenhum mecanismo de controle, um único quadro broadcast circula para sempre pelos dois caminhos.

O efeito cascata é imediato:

1. Um host envia um ARP broadcast
2. O OVS-1 encaminha o quadro para o OVS-2 pelos dois links simultaneamente
3. O OVS-2 reencaminha de volta para o OVS-1 pelos dois links
4. Em milissegundos, a rede está saturada com cópias do mesmo quadro

Isso é chamado de **tempestade de broadcast** (*broadcast storm*). A rede fica inutilizável em segundos.

Além da tempestade, loops causam **instabilidade da tabela MAC**: o switch vê o mesmo endereço MAC chegando alternadamente por portas diferentes e fica reescrevendo a entrada — o que impede o unicast de funcionar corretamente.

### Spanning Tree Protocol (STP — 802.1D)

O STP resolve loops criando uma **árvore lógica sem ciclos** sobre a topologia física:

1. **Eleição da root bridge**: o switch com menor Bridge ID (prioridade + endereço MAC) vira a raiz da árvore. Todos os outros calculam o melhor caminho até ela.

2. **Papéis das portas**:
   * **Root port**: porta com menor custo de caminho até a root bridge (uma por switch não-raiz)
   * **Designated port**: melhor porta em cada segmento de rede (fica em Forwarding)
   * **Blocking port**: porta redundante que criaria loop — mantida em estado Blocking

3. **Estados de porta**:

| Estado | Recebe BPDUs | Aprende MACs | Encaminha frames |
|--------|-------------|--------------|-----------------|
| Blocking | Sim | Não | Não |
| Listening | Sim | Não | Não |
| Learning | Sim | Sim | Não |
| Forwarding | Sim | Sim | Sim |

A transição Blocking → Forwarding leva **30 segundos** (15s em Listening + 15s em Learning). Durante esse tempo, a porta não encaminha tráfego — o que torna o failover lento.

### RSTP (802.1w — Rapid STP)

O RSTP usa negociação direta (*handshake*) entre switches para pular os estados intermediários. A convergência cai para **1–3 segundos** na maioria dos cenários. Os estados Listening e Learning são eliminados; portas passam diretamente de Discarding para Forwarding após a negociação.

### BPDUs

Os switches STP/RSTP se comunicam trocando **Bridge Protocol Data Units (BPDUs)**, quadros Ethernet enviados para o endereço multicast `01:80:c2:00:00:00`. Cada switch envia BPDUs a cada 2 segundos (Hello Time). Eles carregam o Bridge ID, o custo de caminho e as informações de porta — e são a base para toda a eleição e manutenção da topologia.

---

## Parte 1 — Topologia

### Topologia

A topologia é a mesma do Laboratório 04, com a adição de **um segundo link** entre OVS-1 e OVS-2, criando um loop físico:

```
                        [ NAT do GNS3 ]
                               |
                             (WAN)
                          [ pfSense ]
                             (LAN)
                               |
                         trunk (1000,2000)
                               |
      +------------------[ OVS-1 ]------------------+
      |             eth4 (trunk) eth5 (trunk)        |
  tag=1000               |           |           tag=2000
      |             eth1 (trunk) eth4 (trunk)        |
  [Admin1]             [ OVS-2 ]                 [Aluno1]
                       /         \
                 tag=1000      tag=2000
                     |              |
             [UbuntuDesktop]    [Aluno2]
```

> O loop físico está entre OVS-1 e OVS-2: dois links paralelos (OVS-1/eth4 ↔ OVS-2/eth1 e OVS-1/eth5 ↔ OVS-2/eth4). Sem STP, qualquer broadcast causaria uma tempestade.

### Tabela de endereçamento

Idêntica ao Laboratório 04.

| Dispositivo | VLAN | IP | Gateway | Switch |
|-------------|------|----|---------|--------|
| pfSense LAN (em1.1000) | 1000 | 10.0.0.1/24 | — | — |
| pfSense OPT1 (em1.2000) | 2000 | 10.0.1.1/24 | — | — |
| Admin1 | 1000 | 10.0.0.10/24 | 10.0.0.1 | OVS-1 |
| UbuntuDesktop | 1000 | DHCP (10.0.0.100–200) | 10.0.0.1 | OVS-2 |
| Aluno1 | 2000 | 10.0.1.10/24 | 10.0.1.1 | OVS-1 |
| Aluno2 | 2000 | 10.0.1.11/24 | 10.0.1.1 | OVS-2 |

### Passos — Montar a topologia no GNS3

Você pode partir do projeto do Laboratório 04 ou criar um novo seguindo o Lab 04 e adicionando o segundo link:

1. Mantenha todos os dispositivos e conexões do Lab 04.
2. Adicione **uma nova conexão** entre os switches:
   * **OVS-1** `eth5` → **OVS-2** `eth4`
3. Inicie todos os dispositivos.

---

### Perguntas

* Antes de configurar qualquer coisa, quantos caminhos L2 existem entre Admin1 e UbuntuDesktop?
* Por que o pfSense não é afetado pelo loop entre os switches?

---

## Parte 2 — Configurar as portas dos switches

### OVS-1

Se os switches foram iniciados com o segundo link já conectado, `eth5` foi adicionado automaticamente ao `br0` pelo `start.sh`. Caso contrário, adicione manualmente:

```bash
ovs-vsctl --may-exist add-port br0 eth5
ip link set eth5 up
```

Configure as portas:

```bash
# Portas access (sem alteração em relação ao Lab 04)
ovs-vsctl set port eth2 tag=1000
ovs-vsctl set port eth3 tag=2000

# Trunk para o pfSense (sem alteração)
ovs-vsctl set port eth1 trunks=1000,2000

# Trunk para OVS-2 — link 1 (sem alteração)
ovs-vsctl set port eth4 trunks=1000,2000

# Trunk para OVS-2 — link 2 (NOVO: cria o loop)
ovs-vsctl set port eth5 trunks=1000,2000
```

### OVS-2

Da mesma forma, adicione `eth4` ao `br0` se necessário:

```bash
ovs-vsctl --may-exist add-port br0 eth4
ip link set eth4 up
```

Configure as portas:

```bash
# Portas access (sem alteração)
ovs-vsctl set port eth2 tag=1000
ovs-vsctl set port eth3 tag=2000

# Trunk para OVS-1 — link 1 (sem alteração)
ovs-vsctl set port eth1 trunks=1000,2000

# Trunk para OVS-1 — link 2 (NOVO: cria o loop)
ovs-vsctl set port eth4 trunks=1000,2000
```

### Verificação

```bash
ovs-vsctl show
```

No OVS-1, deve mostrar `eth4` e `eth5` ambos com `trunks: [1000, 2000]`. No OVS-2, `eth1` e `eth4`.

---

## Parte 3 — Demonstrando a tempestade de broadcast

Nesta parte, vamos observar o que acontece com o loop ativo e **sem STP habilitado**.

> **Atenção**: a tempestade satura a rede rapidamente. Tenha o comando para interrompê-la digitado e pronto antes de iniciar o broadcast.

### Passo 1 — Confirmar que STP está desabilitado

Em ambos os switches:

```bash
ovs-vsctl get bridge br0 stp_enable
```

Deve retornar `false`.

### Passo 2 — Preparar o comando de emergência

No terminal do **OVS-1**, deixe digitado (mas não execute ainda):

```bash
ip link set eth5 down
```

### Passo 3 — Iniciar captura no trunk inter-switch

Em um terminal do **OVS-1**, capture tráfego no link inter-switch com limite de pacotes:

```bash
tcpdump -i eth4 -e -n -c 100 2>/dev/null
```

### Passo 4 — Gerar um broadcast

No terminal do **Admin1**:

```bash
ping -b -c 3 10.0.0.255
```

### Passo 5 — Observar e interromper

Se a rede travar antes de capturar o output, execute imediatamente no OVS-1:

```bash
ip link set eth5 down
```

A tempestade cessa imediatamente.

### O que você deve ver

No tcpdump, o mesmo quadro aparece repetidamente com velocidade crescente — os 100 pacotes capturados são atingidos em frações de segundo:

```
10:00:01.100 aa:bb:cc:dd:ee:01 > ff:ff:ff:ff:ff:ff, ARP, ...
10:00:01.101 aa:bb:cc:dd:ee:01 > ff:ff:ff:ff:ff:ff, ARP, ...
10:00:01.101 aa:bb:cc:dd:ee:01 > ff:ff:ff:ff:ff:ff, ARP, ...
```

---

### Perguntas

* Por que o unicast também para de funcionar durante a tempestade, mesmo que o destino seja alcançável?
* O pfSense sentiu algum efeito da tempestade? Por quê?

---

## Parte 4 — Habilitando STP (802.1D)

### Passo 1 — Reativar o segundo link (se desativado)

```bash
# No OVS-1
ip link set eth5 up
```

### Passo 2 — Habilitar STP nos dois switches

**No OVS-1:**

```bash
ovs-vsctl set bridge br0 stp_enable=true
```

**No OVS-2:**

```bash
ovs-vsctl set bridge br0 stp_enable=true
```

> Habilite nos dois switches em sequência rápida. Enquanto apenas um tem STP ativo, o outro ainda encaminha por ambas as portas.

### Passo 3 — Aguardar a convergência

O STP clássico leva até **30 segundos** para convergir. Aguarde e então verifique:

```bash
# No OVS-1
ovs-appctl stp/show br0
```

Saída esperada no switch que se tornou root bridge:

```
---- br0 ----
Root ID:
  stp-priority  32768
  stp-system-id  02:00:00:00:00:01
  ...

This bridge is the root.

  Interface  Role       State
  ---------  ----       -----
  eth1       designated forwarding
  eth2       designated forwarding
  eth3       designated forwarding
  eth4       designated forwarding
  eth5       designated forwarding
```

No switch não-raiz, uma das portas inter-switch estará bloqueada:

```
  Interface  Role       State
  ---------  ----       -----
  eth1       root       forwarding
  eth2       designated forwarding
  eth3       designated forwarding
  eth4       alternate  blocking    <-- loop resolvido aqui
```

### Passo 4 — Testar conectividade

```bash
# Admin1 → UbuntuDesktop (L2, mesma VLAN, inter-switch)
ping -c 3 <IP do UbuntuDesktop>

# Admin1 → Aluno2 (L3 via pfSense, inter-VLAN)
ping -c 3 10.0.1.11
```

A rede deve funcionar normalmente, com o loop resolvido pelo STP.

---

### Perguntas

* Qual switch se tornou a root bridge? O que determinou isso?
* Em qual switch e em qual porta o STP aplicou o bloqueio?
* Por que faz sentido bloquear no switch não-raiz em vez de no raiz?

---

## Parte 5 — Controlando a eleição da root bridge

Por padrão, o switch com o **menor endereço MAC** vence a eleição quando as prioridades são iguais (32768). Em redes reais, é importante controlar qual switch é a root bridge para otimizar os caminhos de tráfego.

### Definir prioridade no OVS-1 para forçá-lo como root

```bash
# No OVS-1
ovs-vsctl set bridge br0 other_config:stp-priority=4096
```

> Valores válidos: múltiplos de 4096 (0 a 61440). Menor valor = maior prioridade. Padrão: 32768.

### Aguardar reeleição (~30 segundos) e verificar

```bash
ovs-appctl stp/show br0   # em ambos os switches
```

O OVS-1 deve aparecer como root.

### Controlar qual link fica em Blocking (custo de caminho)

O STP escolhe o caminho pelo **menor custo**. Para garantir que o segundo link (eth4 no OVS-2) fique sempre como standby:

```bash
# No OVS-2 — aumentar o custo do link eth4 (segundo link)
ovs-vsctl set port eth4 other_config:stp-path-cost=200

# No OVS-2 — manter custo menor no eth1 (link principal)
ovs-vsctl set port eth1 other_config:stp-path-cost=100
```

Aguarde a reconvergência e verifique que `eth4` ficou em Blocking.

---

### Perguntas

* Por que é importante poder controlar qual switch é a root bridge em uma rede real?
* O que aconteceria se o administrador definisse prioridade 0 na root bridge?

---

## Parte 6 — Simulando falha de link (failover)

Um dos objetivos do STP é recuperar automaticamente a conectividade quando um link falha.

### Passo 1 — Identificar qual link está ativo

```bash
ovs-appctl stp/show br0   # no OVS-2
```

Identifique qual porta está em Forwarding (link ativo) e qual está em Blocking (standby).

### Passo 2 — Iniciar ping contínuo antes da falha

```bash
# No Admin1 — substitua pelo IP real do UbuntuDesktop
ping 10.0.0.100
```

Deixe rodando em segundo plano enquanto executa o próximo passo.

### Passo 3 — Derrubar o link ativo

Se `eth1` está em Forwarding no OVS-2:

```bash
# No OVS-2
ip link set eth1 down
```

### Passo 4 — Observar o failover

Com STP clássico, observe o ping perder pacotes por **~30 segundos** até o STP desbloquear o link alternativo. Verifique a transição:

```bash
ovs-appctl stp/show br0   # no OVS-2
```

`eth4` deve ter transitado de Blocking para Forwarding após a convergência.

### Passo 5 — Restaurar o link

```bash
# No OVS-2
ip link set eth1 up
```

Observe o STP detectar o link e possivelmente reorganizar a topologia novamente.

---

### Perguntas

* Quantos pacotes de ping foram perdidos durante o failover?
* O que acontece quando `eth1` volta? O STP usa ele imediatamente?

---

## Parte 7 — RSTP (802.1w): convergência rápida

### Passo 1 — Substituir STP por RSTP

**OVS-1:**

```bash
ovs-vsctl set bridge br0 stp_enable=false
ovs-vsctl set bridge br0 rstp_enable=true
```

**OVS-2:**

```bash
ovs-vsctl set bridge br0 stp_enable=false
ovs-vsctl set bridge br0 rstp_enable=true
```

### Passo 2 — Verificar estado RSTP

```bash
ovs-appctl rstp/show br0
```

Os papéis de porta são os mesmos (root, designated, alternate), mas os estados mudam: em vez de Blocking/Listening/Learning/Forwarding, o RSTP usa **Discarding** e **Forwarding**.

### Passo 3 — Repetir o teste de failover

1. Inicie um ping contínuo de Admin1 para UbuntuDesktop.
2. Derrube o link ativo: `ip link set eth1 down` (no OVS-2).
3. Observe quantos pacotes são perdidos.

Com RSTP, o failover deve ocorrer em **1–3 segundos**.

### Passo 4 — Comparar os resultados

| Protocolo | Tempo de convergência | Pacotes perdidos (1 pkt/s) |
|-----------|----------------------|---------------------------|
| STP (802.1D) | ~30 segundos | ~30 pacotes |
| RSTP (802.1w) | 1–3 segundos | 1–3 pacotes |

---

### Perguntas

* Por que o RSTP é muito mais rápido que o STP clássico?
* Em que situações ainda faria sentido usar STP clássico?

---

## Parte 8 — Observando BPDUs

BPDUs são os quadros usados pelos switches para trocar informações de topologia. Vamos capturá-los com tcpdump.

### Capturar BPDUs no trunk

```bash
# No OVS-1 — capturar BPDUs no link inter-switch
tcpdump -i eth4 -e -n stp
```

Você deve ver quadros chegando a cada 2 segundos (Hello Time), destinados ao endereço multicast `01:80:c2:00:00:00`:

```
14:30:01 02:00:00:00:00:01 > 01:80:c2:00:00:00, 802.3, STP 802.1d, Config, bridge-id 8000.02:00:00:00:00:01.8001
14:30:03 02:00:00:00:00:01 > 01:80:c2:00:00:00, 802.3, STP 802.1d, Config, bridge-id 8000.02:00:00:00:00:01.8001
```

| Campo | Significado |
|-------|-------------|
| `8000` | Prioridade em hex (8000 hex = 32768 decimal) |
| `02:00:00:00:00:01` | MAC da bridge emissora |
| `bridge-id` | ID completo da root bridge anunciada |

### Observar BPDUs na porta em Blocking

Conecte o tcpdump na porta que está em Discarding/Blocking no OVS-2:

```bash
# No OVS-2 — se eth4 estiver em Blocking
tcpdump -i eth4 -e -n stp
```

Você deve ver BPDUs **chegando** (o switch ainda os recebe mesmo com a porta bloqueada), mas nenhum tráfego de dados passando.

---

### Perguntas

* Por que a porta em Blocking ainda recebe BPDUs?
* O que acontece se um switch para de receber BPDUs por mais de 20 segundos (Max Age)?

---

## Parte 9 — Desafio final

### Cenário

> *"A empresa quer garantir que o link entre OVS-1/eth4 e OVS-2/eth1 seja sempre o caminho ativo, e que o segundo link (OVS-1/eth5 ↔ OVS-2/eth4) seja sempre o standby. O OVS-1 deve ser sempre a root bridge, independentemente dos endereços MAC dos equipamentos."*

### Requisitos

1. OVS-1 deve ser a root bridge com prioridade que garanta isso independentemente do MAC
2. O link eth4↔eth1 deve ser sempre o caminho ativo (Forwarding no OVS-2)
3. O link eth5↔eth4 deve ser sempre o standby (Discarding no OVS-2)
4. Usando RSTP, ao derrubar o link principal, a rede deve se recuperar em menos de 5 segundos

### Validação

```bash
# Confirmar root bridge e portas ativas
ovs-appctl rstp/show br0   # nos dois switches

# Testar failover — derrubar link principal no OVS-2
ip link set eth1 down

# Medir recuperação com ping contínuo do Admin1
ping 10.0.0.100

# Restaurar
ip link set eth1 up
```

---

## Entregável

* Print do `ovs-appctl stp/show br0` nos dois switches após a convergência STP
* Print do `ovs-appctl rstp/show br0` após ativação do RSTP
* Registro do número de pacotes perdidos no failover (STP vs RSTP)
* Print do tcpdump mostrando BPDUs
* Respostas às perguntas de cada parte
* Configuração usada no desafio (prioridades e custos de caminho)

---

## Conceitos abordados

| Conceito | Onde foi abordado |
|----------|-------------------|
| Tempestade de broadcast | Parte 3 |
| Eleição da root bridge | Partes 4, 5 |
| Estados de porta STP | Parte 4 |
| Controle de topologia (prioridade, custo) | Parte 5 |
| Failover automático | Parte 6 |
| RSTP vs STP clássico | Parte 7 |
| BPDUs | Parte 8 |

---

## Próximos passos

Em aulas futuras:

* Roteamento estático entre sites distintos
* VPN site-a-site com pfSense
* Introdução ao roteamento dinâmico (OSPF)
