# Laboratório 03 — VLANs em múltiplos switches com trunk inter-switch

## Objetivo

Este laboratório estende o conceito de VLANs para um cenário com dois switches interligados por um trunk. O pfSense continua como gateway e firewall, mas agora as VLANs se propagam por dois switches OVS distintos.

Ao final, o aluno será capaz de:

* Configurar um trunk entre dois switches OVS
* Verificar que hosts da mesma VLAN em switches diferentes se comunicam diretamente (sem roteamento)
* Verificar que o isolamento entre VLANs é mantido mesmo cruzando switches
* Entender o caminho completo que um pacote percorre em cada cenário

---

## Duração estimada

Aproximadamente **3h**

---

## Pré-requisitos

* Ter concluído o Laboratório 02
* Templates disponíveis no GNS3:
  * Container: `ubuntu-net` (insightlab/ubuntu-net:1.0)
  * Máquina virtual: `UbuntuDesktop` (QEMU — com interface gráfica e Firefox)
  * Switch: Open vSwitch (insightlab/ovs:1.1)
  * Roteador/Firewall: pfSense (QEMU)
  * Cloud: NAT

---

## Conceitos importantes

### Trunk inter-switch

No Laboratório 02, usamos um trunk entre o pfSense e um único switch OVS. Agora adicionamos um segundo trunk: entre dois switches.

Quando dois switches são interligados por um trunk, os quadros Ethernet **mantêm suas tags 802.1Q** ao cruzar o link. Isso permite que a mesma VLAN exista em ambos os switches sem que os hosts precisem saber que estão em equipamentos diferentes.

```
OVS-1                                    OVS-2
  |── tag=1000 ── [Admin1]                 |── tag=1000 ── [UbuntuDesktop]
  |── tag=2000 ── [Aluno1]                 |── tag=2000 ── [Aluno2]
  |── trunk(1000,2000) ─────────────────── trunk(1000,2000)
  |── trunk(1000,2000) ── [pfSense]
```

### Caminhos possíveis

| Origem | Destino | Caminho | Camada |
|--------|---------|---------|--------|
| Admin1 | UbuntuDesktop | OVS-1 → trunk → OVS-2 | L2 (mesma VLAN) |
| Aluno1 | Aluno2 | OVS-1 → trunk → OVS-2 | L2 (mesma VLAN) |
| Admin1 | Aluno1 | OVS-1 → pfSense → OVS-1 | L3 (inter-VLAN) |
| UbuntuDesktop | Aluno2 | OVS-2 → trunk → OVS-1 → pfSense → OVS-1 → trunk → OVS-2 | L3 (inter-VLAN) |

> O pfSense não precisa saber quantos switches existem abaixo dele — ele enxerga apenas o trunk na sua interface LAN e roteia entre as VLANs normalmente.

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
      +------------------[ OVS-1 ]------------------+
      |                        |                     |
  tag=1000              trunk (1000,2000)         tag=2000
      |                        |                     |
  [Admin1]              [ OVS-2 ]               [Aluno1]
                        /         \
                  tag=1000      tag=2000
                      |              |
              [UbuntuDesktop]    [Aluno2]
```

### Tabela de endereçamento

| Dispositivo | VLAN | IP | Gateway | Switch |
|-------------|------|----|---------|--------|
| pfSense WAN | — | DHCP (via NAT) | — | — |
| pfSense LAN (em1.1000) | 1000 | 10.0.0.1/24 | — | — |
| pfSense OPT1 (em1.2000) | 2000 | 10.0.1.1/24 | — | — |
| Admin1 | 1000 | 10.0.0.10/24 | 10.0.0.1 | OVS-1 |
| UbuntuDesktop | 1000 | DHCP (10.0.0.100–200) | 10.0.0.1 | OVS-2 |
| Aluno1 | 2000 | 10.0.1.10/24 | 10.0.1.1 | OVS-1 |
| Aluno2 | 2000 | 10.0.1.11/24 | 10.0.1.1 | OVS-2 |

---

### Passos — Montar a topologia no GNS3

1. Adicione ao projeto:
   * 1 **NAT** (cloud)
   * 1 **pfSense** (QEMU)
   * 2 **Open vSwitch** (renomeie para OVS-1 e OVS-2)
   * 3 containers **ubuntu-net** (renomeie para Admin1, Aluno1, Aluno2)
   * 1 máquina virtual **UbuntuDesktop** (QEMU)

2. Conecte:
   * **NAT** → **pfSense** interface `e0` (WAN)
   * **pfSense** `e1` (LAN) → **OVS-1** `eth1`
   * **Admin1** eth0 → **OVS-1** `eth2`
   * **Aluno1** eth0 → **OVS-1** `eth3`
   * **OVS-1** `eth4` → **OVS-2** `eth1` *(trunk inter-switch)*
   * **UbuntuDesktop** eth0 → **OVS-2** `eth2`
   * **Aluno2** eth0 → **OVS-2** `eth3`

> **Lembrete:** nunca utilizar `eth0` dos switches OVS.

3. Inicie todos os dispositivos.

---

### Perguntas

* Por que o pfSense se conecta apenas ao OVS-1 e não ao OVS-2?
* Quantos trunks existem nesta topologia? Qual a função de cada um?

---

## Parte 2 — Configurar o OVS-1

### Portas access

No terminal do OVS-1:

```bash
# VLAN 1000 — Administração
ovs-vsctl set port eth2 tag=1000

# VLAN 2000 — Alunos
ovs-vsctl set port eth3 tag=2000
```

### Porta trunk para o pfSense

```bash
ovs-vsctl set port eth1 trunks=1000,2000
```

### Porta trunk para o OVS-2

```bash
ovs-vsctl set port eth4 trunks=1000,2000
```

### Verificação

```bash
ovs-vsctl show
```

Deve mostrar:

* `eth1` com `trunks: [1000, 2000]` (pfSense)
* `eth2` com `tag: 1000`
* `eth3` com `tag: 2000`
* `eth4` com `trunks: [1000, 2000]` (OVS-2)

---

### Perguntas

* Por que tanto `eth1` quanto `eth4` são configurados como trunk com as mesmas VLANs?
* O que aconteceria se `eth4` fosse configurado como access em vez de trunk?

---

## Parte 3 — Configurar o OVS-2

### Porta trunk para o OVS-1

No terminal do OVS-2:

```bash
ovs-vsctl set port eth1 trunks=1000,2000
```

### Portas access

```bash
# VLAN 1000 — Administração
ovs-vsctl set port eth2 tag=1000

# VLAN 2000 — Alunos
ovs-vsctl set port eth3 tag=2000
```

### Verificação

```bash
ovs-vsctl show
```

Deve mostrar:

* `eth1` com `trunks: [1000, 2000]` (OVS-1)
* `eth2` com `tag: 1000`
* `eth3` com `tag: 2000`

---

### Perguntas

* O OVS-2 precisa saber que existe um pfSense na rede? Por quê?
* Se adicionarmos um terceiro switch OVS-3 conectado ao OVS-2, o que precisaria ser configurado?

---

## Parte 4 — Configurar o pfSense pelo console

A configuração do pfSense é idêntica ao Laboratório 02 — ele enxerga apenas o trunk na sua interface LAN, independentemente de quantos switches existem abaixo.

### Passo 1 — Assign Interfaces

No console do pfSense, selecione a opção **1) Assign Interfaces**.

```
Should VLANs be set up now [y|n]? y
```

#### VLAN 1000 (Administração)

```
Enter the parent interface name for the new VLAN (or nothing if finished): em1
Enter the VLAN tag (1 to 4094): 1000
```

#### VLAN 2000 (Alunos)

```
Enter the parent interface name for the new VLAN (or nothing if finished): em1
Enter the VLAN tag (1 to 4094): 2000
```

#### Finalizar

```
Enter the parent interface name for the new VLAN (or nothing if finished): [Enter]
```

### Passo 2 — Atribuir as interfaces

```
Enter the WAN interface name or 'a' for auto-detection: em0
Enter the LAN interface name or 'a' for auto-detection: em1.1000
Enter the Optional 1 interface name or 'a' for auto-detection (or nothing if finished): em1.2000
Enter the Optional 2 interface name or 'a' for auto-detection (or nothing if finished): [Enter]
Do you want to proceed [y|n]? y
```

### Passo 3 — Configurar IPs e DHCP

Selecione a opção **2) Set interface(s) IP address**.

#### LAN (VLAN 1000 — Administração)

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

```
Enter the new OPT1 IPv4 address: 10.0.1.1
Enter the new OPT1 IPv4 subnet bit count: 24
For a WAN, enter the upstream gateway address.
For all other interfaces, press <ENTER> for none: [Enter]
Do you want to enable the DHCP server on OPT1? [y|n]: y
Enter the start address of the client address range: 10.0.1.100
Enter the end address of the client address range: 10.0.1.200
```

### Verificação

```
WAN  (em0)      ->  IP via DHCP (NAT)
LAN  (em1.1000) ->  10.0.0.1/24
OPT1 (em1.2000) ->  10.0.1.1/24
```

---

## Parte 5 — Configurar os hosts

### Admin1

```bash
ip addr add 10.0.0.10/24 dev eth0
ip link set eth0 up
ip route add default via 10.0.0.1
```

### UbuntuDesktop

Como o DHCP está ativo na VLAN 1000, basta desativar e reativar a interface:

```bash
nmcli con down "Wired connection 1" && nmcli con up "Wired connection 1"
```

Verifique se o IP está na faixa `10.0.0.100–10.0.0.200`:

```bash
ip addr show eth0
ip route
```

> Se o IP não for atribuído automaticamente, configure manualmente:
>
> ```bash
> nmcli con mod "Wired connection 1" ipv4.addresses 10.0.0.11/24 ipv4.gateway 10.0.0.1 ipv4.dns "8.8.8.8" ipv4.method manual
> nmcli con up "Wired connection 1"
> ```

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

## Parte 6 — Regras de firewall e DNS no pfSense

No **UbuntuDesktop**, abra o **Firefox** e acesse `http://10.0.0.1` (usuário: `admin`, senha: `15lab66infra`).

### Passo 1 — Verificar regra da LAN

A interface LAN já possui uma regra padrão que permite todo o tráfego. Caso não esteja presente:

1. Vá em **Firewall > Rules > LAN**
2. Clique em **+ Add** e configure:
   * **Action:** Pass / **Protocol:** Any / **Source:** LAN net / **Destination:** Any
3. **Save** e **Apply Changes**

### Passo 2 — Adicionar regra para OPT1

Por padrão, OPT1 não possui regras — todo o tráfego da VLAN 2000 é bloqueado.

1. Vá em **Firewall > Rules > OPT1**
2. Clique em **+ Add** e configure:
   * **Action:** Pass / **Interface:** OPT1 / **Protocol:** Any / **Source:** OPT1 net / **Destination:** Any
3. **Save** e **Apply Changes**

### Passo 3 — Configurar DNS no DHCP

#### LAN (VLAN 1000)

1. Vá em **Services > DHCP Server > LAN**
2. **DNS Server 1:** `8.8.8.8` / **DNS Server 2:** `1.1.1.1`
3. **Save**

#### OPT1 (VLAN 2000)

1. Vá em **Services > DHCP Server > OPT1**
2. **DNS Server 1:** `8.8.8.8` / **DNS Server 2:** `1.1.1.1`
3. **Save**

---

## Parte 7 — Testes de conectividade

### Testes — Mesma VLAN, switches diferentes *(conceito novo)*

```bash
# Admin1 → UbuntuDesktop (VLAN 1000, OVS-1 → OVS-2): deve FUNCIONAR
ping -c 3 <IP do UbuntuDesktop>

# Aluno1 → Aluno2 (VLAN 2000, OVS-1 → OVS-2): deve FUNCIONAR
ping -c 3 10.0.1.11
```

> Estes testes validam que o trunk inter-switch propaga corretamente as VLANs. O pacote **não passa pelo pfSense** — trafega diretamente entre os dois switches em camada 2.

### Testes — Inter-VLAN (via pfSense)

```bash
# Admin1 → Aluno1 (VLAN 1000 → 2000, mesmo switch)
ping -c 3 10.0.1.10

# Admin1 → Aluno2 (VLAN 1000 → 2000, switches diferentes)
ping -c 3 10.0.1.11

# UbuntuDesktop → Aluno1 (VLAN 1000 → 2000, switches diferentes)
ping -c 3 10.0.1.10
```

### Testes — Internet

```bash
# De qualquer host
ping -c 3 8.8.8.8
ping -c 3 google.com
```

---

### Perguntas

* Quando Admin1 faz ping para UbuntuDesktop, o pacote passa pelo pfSense? Por quê?
* Quando Admin1 faz ping para Aluno2, quantos switches o pacote atravessa? Desenhe o caminho.
* Se o trunk entre OVS-1 e OVS-2 for removido, qual comunicação deixa de funcionar?

---

## Parte 8 — Observando o tráfego no trunk inter-switch

### Captura no trunk inter-switch (OVS-1 eth4)

```bash
tcpdump -i eth4 -e -n
```

Em outro terminal, gere os seguintes tráfegos e observe as capturas:

1. **Admin1 → UbuntuDesktop** (mesma VLAN, L2 inter-switch)
2. **Admin1 → Aluno2** (inter-VLAN, L3 via pfSense + L2 inter-switch)
3. **Admin1 → Aluno1** (inter-VLAN, mesmo switch — *este tráfego aparece no trunk eth4?*)

### Comparação dos trunks

| Interface | Destino | Tipos de tráfego esperados |
|-----------|---------|---------------------------|
| OVS-1 `eth1` | pfSense | tráfego inter-VLAN (roteado) |
| OVS-1 `eth4` | OVS-2 | tráfego intra-VLAN inter-switch + tráfego roteado destinado a OVS-2 |

---

### Perguntas

* O tráfego Admin1 → UbuntuDesktop aparece com tag 802.1Q no trunk inter-switch?
* O tráfego Admin1 → Aluno1 (mesmo switch) aparece no trunk `eth4`? Por quê?
* Ao capturar no trunk do pfSense (`eth1`), qual tráfego você vê que não aparece no trunk inter-switch (`eth4`)?

---

## Parte 9 — Desafio final

### Cenário

> *"A empresa tem dois andares. O setor de Administração e o setor de Alunos têm máquinas nos dois andares. A política de segurança determina: Alunos só podem acessar a Internet (HTTP, HTTPS e DNS) e não podem acessar nenhuma máquina da Administração. A Administração tem acesso irrestrito."*

### Requisitos

| Origem | Destino | Resultado esperado |
|--------|---------|-------------------|
| Aluno1 / Aluno2 | Internet (HTTP/HTTPS) | ✅ Deve funcionar |
| Aluno1 / Aluno2 | 10.0.0.0/24 (Administração) | ❌ Deve falhar |
| Aluno1 / Aluno2 | ping para qualquer destino externo | ❌ Deve falhar |
| Admin1 / UbuntuDesktop | qualquer destino | ✅ Deve funcionar |

### Dicas

* As regras de firewall ficam no pfSense, independentemente de onde os hosts estão fisicamente
* A topologia com dois switches é **transparente** para o pfSense
* Regras em **Firewall > Rules > OPT1** são avaliadas de cima para baixo
* Bloqueios específicos devem vir **antes** de permissões gerais

### Validação

```bash
# A partir de Aluno1 ou Aluno2:

# Deve FUNCIONAR
curl http://example.com
curl -k https://google.com

# Deve FALHAR
ping -c 3 10.0.0.10
ping -c 3 10.0.0.11
ping -c 3 8.8.8.8
```

```bash
# A partir de Admin1 ou UbuntuDesktop:

# Tudo deve FUNCIONAR
ping -c 3 8.8.8.8
ping -c 3 10.0.1.10
curl -k https://google.com
```

---

## Entregável

* Print da topologia montada no GNS3
* Print da configuração dos dois switches (`ovs-vsctl show` em cada um)
* Print dos testes de ping (mesma VLAN entre switches, inter-VLAN, Internet)
* Captura do `tcpdump` no trunk inter-switch com tráfego L2 e L3
* Print das regras de firewall do desafio final
* Respostas às perguntas de cada parte

---

## Conceitos abordados

| Conceito | Onde foi abordado |
|----------|-------------------|
| Trunk inter-switch | Partes 2, 3, 8 |
| Propagação de VLANs entre switches | Partes 7, 8 |
| Caminho L2 vs L3 | Parte 7 |
| Router-on-a-stick com múltiplos switches | Partes 4, 7 |
| Firewall inter-VLAN | Partes 6, 9 |
| DHCP por VLAN | Parte 4 |
| Análise de tráfego 802.1Q | Parte 8 |

---

## Próximos passos

Em aulas futuras:

* Spanning Tree Protocol (STP) — o que acontece quando há loops entre switches?
* Roteamento estático entre sites distintos
* VPN entre redes remotas
