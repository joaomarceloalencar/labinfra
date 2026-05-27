# Laboratório 05 — Roteamento Estático entre Sites

## Objetivo

Este laboratório introduz o conceito de roteamento entre redes IP distintas. Até agora, todos os hosts de cada laboratório estavam em redes alcançáveis diretamente por um único pfSense. Agora vamos conectar dois sites independentes — cada um com seu próprio pfSense e sub-rede — usando rotas estáticas para permitir a comunicação entre eles.

Ao final, o aluno será capaz de:

* Entender quando o roteamento é necessário (hosts em sub-redes diferentes)
* Configurar rotas estáticas no pfSense via interface web
* Entender o conceito de próximo salto (*next-hop*) e gateway
* Diagnosticar o caminho de pacotes entre sites com `traceroute`
* Aplicar regras de firewall para controlar o tráfego inter-sites

---

## Duração estimada

Aproximadamente **3h**

---

## Pré-requisitos

* Ter concluído o Laboratório 03 (pfSense básico com VLANs)
* Templates disponíveis no GNS3:
  * Container: `ubuntu-net` (insightlab/ubuntu-net:1.0)
  * Máquina virtual: `UbuntuDesktop` (QEMU — com interface gráfica e Firefox)
  * Switch: Open vSwitch (insightlab/ovs:1.1)
  * Roteador/Firewall: pfSense (QEMU)
  * Cloud: NAT

---

## Conceitos importantes

### O que é roteamento?

Um switch L2 encaminha quadros com base em endereços MAC — mas só funciona dentro de uma mesma rede (mesmo segmento L2). Quando dois hosts estão em **sub-redes IP diferentes**, eles não conseguem se comunicar diretamente: precisam de um **roteador** intermediário.

O roteador consulta sua **tabela de roteamento** para decidir por onde encaminhar cada pacote. A tabela lista destinos conhecidos e o *next-hop* para alcançar cada um.

### Rotas estáticas

Uma rota estática é configurada manualmente pelo administrador. Ela instrui o roteador: *"para alcançar a rede X, envie o pacote para o endereço Y"*.

```
Destino:       10.1.0.0/24
Próximo salto: 192.168.100.2
```

Rotas estáticas são simples e previsíveis, mas não se adaptam automaticamente a falhas de topologia. Em redes maiores, protocolos de roteamento dinâmico (como OSPF) automatizam esse processo — tema de laboratórios futuros.

### Link ponto-a-ponto (/30)

O link dedicado entre dois roteadores normalmente usa uma sub-rede /30, que comporta apenas dois endereços de host. Isso evita desperdício de endereços em um segmento que terá apenas dois dispositivos.

```
192.168.100.0/30
  .1 — pfSense-A (OPT1)
  .2 — pfSense-B (OPT1)
```

### Caminho de um pacote entre sites

```
Admin-A (10.0.0.10)
  → pfSense-A LAN  (10.0.0.1)       [gateway padrão do Admin-A]
  → pfSense-A OPT1 (192.168.100.1)  [rota: 10.1.0.0/24 via 192.168.100.2]
  → pfSense-B OPT1 (192.168.100.2)  [link inter-sites]
  → pfSense-B LAN  (10.1.0.1)       [10.1.0.0/24 é rede diretamente conectada]
  → Admin-B (10.1.0.10)             [destino final]
```

O retorno percorre o caminho inverso, usando a rota configurada no pfSense-B.

---

## Parte 1 — Topologia

### Topologia

```
    [NAT-A]                                         [NAT-B]
       |                                               |
  [pfSense-A] ─── link inter-sites (192.168.100.0/30) ─── [pfSense-B]
  em0=WAN(NAT)  em2                            em2  em0=WAN(NAT)
  em1=LAN                                           em1=LAN
       |                                               |
    [OVS-A]                                        [OVS-B]
    /       \                                      /       \
[UbDt-A] [Admin-A]                           [UbDt-B] [Admin-B]
```

### Tabela de endereçamento

| Dispositivo | Interface | IP | Sub-rede |
|-------------|-----------|-----|---------|
| pfSense-A | em0 (WAN) | DHCP | NAT |
| pfSense-A | em1 (LAN) | 10.0.0.1/24 | Site A |
| pfSense-A | em2 (OPT1) | 192.168.100.1/30 | Inter-sites |
| pfSense-B | em0 (WAN) | DHCP | NAT |
| pfSense-B | em1 (LAN) | 10.1.0.1/24 | Site B |
| pfSense-B | em2 (OPT1) | 192.168.100.2/30 | Inter-sites |
| UbuntuDesktop-A | eth0 | DHCP (10.0.0.100–200) | Site A |
| Admin-A | eth0 | 10.0.0.10/24 | Site A |
| UbuntuDesktop-B | eth0 | DHCP (10.1.0.100–200) | Site B |
| Admin-B | eth0 | 10.1.0.10/24 | Site B |

### Rotas estáticas a configurar

| Roteador | Destino | Próximo salto |
|----------|---------|---------------|
| pfSense-A | 10.1.0.0/24 | 192.168.100.2 |
| pfSense-B | 10.0.0.0/24 | 192.168.100.1 |

### Passos — Montar a topologia no GNS3

1. Adicione ao projeto:
   * 2 **NAT** (clouds): NAT-A e NAT-B
   * 2 **pfSense** (QEMU): pfSense-A e pfSense-B
   * 2 **Open vSwitch**: OVS-A e OVS-B
   * 2 containers **ubuntu-net**: Admin-A e Admin-B
   * 2 **UbuntuDesktop** (QEMU): UbuntuDesktop-A e UbuntuDesktop-B

2. Conecte:
   * **NAT-A** → **pfSense-A** `e0` (WAN)
   * **pfSense-A** `e1` → **OVS-A** `eth1`
   * **pfSense-A** `e2` → **pfSense-B** `e2` *(link inter-sites)*
   * **pfSense-B** `e1` → **OVS-B** `eth1`
   * **NAT-B** → **pfSense-B** `e0` (WAN)
   * **UbuntuDesktop-A** `eth0` → **OVS-A** `eth2`
   * **Admin-A** `eth0` → **OVS-A** `eth3`
   * **UbuntuDesktop-B** `eth0` → **OVS-B** `eth2`
   * **Admin-B** `eth0` → **OVS-B** `eth3`

3. Inicie todos os dispositivos.

> **Nota sobre os switches OVS:** neste laboratório não usamos VLANs. O `start.sh` já adiciona todas as interfaces ao `br0`, de modo que os switches funcionam como um L2 simples sem configuração adicional.

---

### Perguntas

* Por que são necessários dois pfSenses neste laboratório?
* Qual é a função do link 192.168.100.0/30 entre os dois pfSenses?

---

## Parte 2 — Configurar pfSense-A pelo console

### Passo 1 — Assign Interfaces (opção 1)

```
Should VLANs be set up now [y|n]? n

Enter the WAN interface name or 'a' for auto-detection: em0
Enter the LAN interface name or 'a' for auto-detection: em1
Enter the Optional 1 interface name or 'a' for auto-detection (or nothing if finished): em2
Enter the Optional 2 interface name or 'a' for auto-detection (or nothing if finished): [Enter]
Do you want to proceed [y|n]? y
```

### Passo 2 — Configurar IPs (opção 2)

#### WAN (em0) — Internet via NAT

Selecione a interface **WAN**. Confirme DHCP quando perguntado:

```
Configure IPv4 address WAN interface via DHCP? [y|n]: y
```

#### LAN (em1) — Rede do Site A

```
Enter the new LAN IPv4 address: 10.0.0.1
Enter the new LAN IPv4 subnet bit count: 24
For all other interfaces, press <ENTER> for none: [Enter]
Do you want to enable the DHCP server on LAN? [y|n]: y
Enter the start address of the client address range: 10.0.0.100
Enter the end address of the client address range: 10.0.0.200
```

#### OPT1 (em2) — Link inter-sites

```
Enter the new OPT1 IPv4 address: 192.168.100.1
Enter the new OPT1 IPv4 subnet bit count: 30
For all other interfaces, press <ENTER> for none: [Enter]
Do you want to enable the DHCP server on OPT1? [y|n]: n
```

### Verificação

```
WAN  (em0) → DHCP (internet via NAT)
LAN  (em1) → 10.0.0.1/24
OPT1 (em2) → 192.168.100.1/30
```

---

## Parte 3 — Configurar pfSense-B pelo console

Repita o processo no pfSense-B, com os seguintes valores:

#### WAN (em0)

```
Configure IPv4 address WAN interface via DHCP? [y|n]: y
```

#### LAN (em1) — Rede do Site B

```
Enter the new LAN IPv4 address: 10.1.0.1
Enter the new LAN IPv4 subnet bit count: 24
For all other interfaces, press <ENTER> for none: [Enter]
Do you want to enable the DHCP server on LAN? [y|n]: y
Enter the start address of the client address range: 10.1.0.100
Enter the end address of the client address range: 10.1.0.200
```

#### OPT1 (em2) — Link inter-sites

```
Enter the new OPT1 IPv4 address: 192.168.100.2
Enter the new OPT1 IPv4 subnet bit count: 30
For all other interfaces, press <ENTER> for none: [Enter]
Do you want to enable the DHCP server on OPT1? [y|n]: n
```

### Verificação

```
WAN  (em0) → DHCP (internet via NAT)
LAN  (em1) → 10.1.0.1/24
OPT1 (em2) → 192.168.100.2/30
```

---

## Parte 4 — Configurar os hosts

### Admin-A

```bash
ip addr add 10.0.0.10/24 dev eth0
ip link set eth0 up
ip route add default via 10.0.0.1
```

### UbuntuDesktop-A

Como o DHCP está ativo no Site A, reconecte a interface:

```bash
nmcli con down "Wired connection 1" && nmcli con up "Wired connection 1"
ip addr show eth0
```

Verifique que o IP está na faixa `10.0.0.100–200`.

### Admin-B

```bash
ip addr add 10.1.0.10/24 dev eth0
ip link set eth0 up
ip route add default via 10.1.0.1
```

### UbuntuDesktop-B

```bash
nmcli con down "Wired connection 1" && nmcli con up "Wired connection 1"
ip addr show eth0
```

Verifique que o IP está na faixa `10.1.0.100–200`.

---

## Parte 5 — Testar conectividade intra-site

Antes de configurar as rotas, confirme que cada site funciona de forma independente.

### Site A (a partir do Admin-A)

```bash
# Gateway
ping -c 3 10.0.0.1

# UbuntuDesktop-A
ping -c 3 <IP do UbuntuDesktop-A>

# Internet
ping -c 3 8.8.8.8
```

### Site B (a partir do Admin-B)

```bash
ping -c 3 10.1.0.1
ping -c 3 <IP do UbuntuDesktop-B>
ping -c 3 8.8.8.8
```

### Confirmar que o inter-site ainda NÃO funciona

```bash
# Admin-A → Admin-B (deve FALHAR)
ping -c 3 10.1.0.10
```

> O pfSense-A não possui rota para 10.1.0.0/24 — o pacote é descartado.

---

### Perguntas

* O que acontece com o pacote de Admin-A para Admin-B neste momento? Onde ele é descartado?
* Por que o pfSense-A não sabe automaticamente que 10.1.0.0/24 existe?

---

## Parte 6 — Configurar rotas estáticas

Acesse a interface web de cada pfSense via Firefox no UbuntuDesktop do respectivo site (usuário: `admin`, senha: `15lab66infra`).

No pfSense, antes de criar uma rota estática é necessário definir o **gateway** (próximo salto) como um objeto separado.

### pfSense-A — via UbuntuDesktop-A (`http://10.0.0.1`)

#### Passo 1 — Criar o gateway para o Site B

1. Vá em **System > Routing > Gateways**
2. Clique em **+ Add** e configure:
   * **Interface:** OPT1
   * **Name:** `GW_SITE_B`
   * **Gateway:** `192.168.100.2`
3. **Save** e **Apply Changes**

#### Passo 2 — Criar a rota estática

1. Vá em **System > Routing > Static Routes**
2. Clique em **+ Add** e configure:
   * **Destination network:** `10.1.0.0 / 24`
   * **Gateway:** `GW_SITE_B – 192.168.100.2`
3. **Save** e **Apply Changes**

### pfSense-B — via UbuntuDesktop-B (`http://10.1.0.1`)

#### Passo 1 — Criar o gateway para o Site A

1. **System > Routing > Gateways > Add**:
   * **Interface:** OPT1
   * **Name:** `GW_SITE_A`
   * **Gateway:** `192.168.100.1`
2. **Save** e **Apply Changes**

#### Passo 2 — Criar a rota estática

1. **System > Routing > Static Routes > Add**:
   * **Destination network:** `10.0.0.0 / 24`
   * **Gateway:** `GW_SITE_A – 192.168.100.1`
2. **Save** e **Apply Changes**

---

### Perguntas

* Por que é necessário configurar a rota nos **dois** pfSenses? Configurar apenas no pfSense-A não seria suficiente?
* O pfSense-A precisa de uma rota para alcançar 192.168.100.2? Por quê?

---

## Parte 7 — Configurar firewall para o link inter-sites

Por padrão, a interface OPT1 não possui regras de firewall — todo o tráfego recebido por ela é bloqueado, mesmo com as rotas configuradas.

### pfSense-A — Firewall > Rules > OPT1

1. Clique em **+ Add** e configure:
   * **Action:** Pass
   * **Interface:** OPT1
   * **Protocol:** Any
   * **Source:** Any
   * **Destination:** Any
2. **Save** e **Apply Changes**

### pfSense-B — Firewall > Rules > OPT1

Repita os mesmos passos no pfSense-B.

> **Por que nos dois?** O tráfego originado no Site A entra pela OPT1 do pfSense-B; o tráfego do Site B entra pela OPT1 do pfSense-A. Cada pfSense precisa permitir o tráfego que chega pela sua própria OPT1.

---

## Parte 8 — Testes de conectividade inter-site

### Testes de ping

```bash
# Admin-A → pfSense-B LAN (gateway do Site B)
ping -c 3 10.1.0.1

# Admin-A → Admin-B
ping -c 3 10.1.0.10

# Admin-A → UbuntuDesktop-B
ping -c 3 <IP do UbuntuDesktop-B>

# Admin-B → Admin-A
ping -c 3 10.0.0.10

# Ambos os sites → internet
ping -c 3 8.8.8.8
```

### Matriz de conectividade esperada

| Origem | Destino | Esperado |
|--------|---------|---------|
| Admin-A | Admin-B | ✅ |
| Admin-B | Admin-A | ✅ |
| Admin-A | 8.8.8.8 | ✅ |
| Admin-B | 8.8.8.8 | ✅ |
| Admin-A | pfSense-B LAN | ✅ |
| Admin-A | 192.168.100.2 | ✅ |

---

## Parte 9 — Analisando o caminho com traceroute

O `traceroute` revela cada salto que o pacote percorre até o destino. Use-o para visualizar o roteamento inter-sites na prática.

### Traceroute de Site A para Site B

```bash
# No Admin-A
traceroute 10.1.0.10
```

Saída esperada:

```
traceroute to 10.1.0.10 (10.1.0.10)
 1  10.0.0.1      (pfSense-A LAN — gateway padrão do Admin-A)
 2  192.168.100.2 (pfSense-B OPT1 — next-hop do link inter-sites)
 3  10.1.0.10     (Admin-B — destino)
```

### Traceroute de Site B para Site A

```bash
# No Admin-B
traceroute 10.0.0.10
```

```
 1  10.1.0.1      (pfSense-B LAN)
 2  192.168.100.1 (pfSense-A OPT1)
 3  10.0.0.10     (Admin-A)
```

### Verificar a tabela de roteamento dos pfSenses

No pfSense, acesse **Diagnostics > Routes** ou via console (opção 8 — Shell):

```bash
netstat -rn
```

Identifique as linhas referentes a:
* `10.1.0.0/24` via `192.168.100.2` (no pfSense-A)
* `10.0.0.0/24` via `192.168.100.1` (no pfSense-B)
* Redes diretamente conectadas (LAN e OPT1 de cada pfSense)

---

### Perguntas

* No traceroute de Admin-A para Admin-B, por que o segundo salto é `192.168.100.2` e não `10.1.0.1`?
* Se um terceiro site (Site C, sub-rede 10.2.0.0/24) fosse adicionado com seu próprio pfSense, o que precisaria ser configurado nos três roteadores?

---

## Parte 10 — Desafio final

### Cenário

> *"A empresa possui duas filiais: Site A (Administração) e Site B (Desenvolvimento). Por política de segurança, o Site B pode iniciar conexões com o Site A (para acessar servidores internos), mas o Site A não deve iniciar conexões com hosts do Site B. O tráfego de internet de cada site deve permanecer independente."*

### Requisitos

| Origem | Destino | Resultado esperado |
|--------|---------|-------------------|
| Admin-B | Admin-A (10.0.0.10) | ✅ Deve funcionar |
| Admin-A | Admin-B (10.1.0.10) | ❌ Deve falhar |
| Admin-A | Internet (8.8.8.8) | ✅ Deve funcionar |
| Admin-B | Internet (8.8.8.8) | ✅ Deve funcionar |

### Dicas

* As regras de firewall do pfSense são avaliadas na interface de **entrada** do pacote
* Para bloquear que o Site A inicie conexões com o Site B: na OPT1 do pfSense-A, bloqueie tráfego de origem 10.0.0.0/24 com destino 10.1.0.0/24
* Para permitir que o Site B inicie conexões com o Site A: na OPT1 do pfSense-B, permita tráfego de origem 10.1.0.0/24 com destino 10.0.0.0/24
* O pfSense usa firewall com estado (*stateful*) — os pacotes de retorno de conexões iniciadas pelo Site B são permitidos automaticamente no Site A

### Validação

```bash
# De Admin-B — deve FUNCIONAR
ping -c 3 10.0.0.10

# De Admin-A — deve FALHAR
ping -c 3 10.1.0.10

# Internet em ambos os sites — deve FUNCIONAR
ping -c 3 8.8.8.8
```

---

## Entregável

* Print da topologia montada no GNS3
* Print das tabelas de roteamento de ambos os pfSenses (`Diagnostics > Routes`)
* Print dos testes de ping inter-site
* Print do traceroute mostrando os saltos entre os sites
* Print das regras de firewall do desafio final
* Respostas às perguntas de cada parte

---

## Conceitos abordados

| Conceito | Onde foi abordado |
|----------|-------------------|
| Roteamento entre sub-redes | Partes 5, 6, 8 |
| Tabela de roteamento | Parte 9 |
| Rotas estáticas | Parte 6 |
| Gateway e próximo salto | Partes 1, 6 |
| Link ponto-a-ponto /30 | Partes 1, 2, 3 |
| Firewall OPT1 | Parte 7 |
| traceroute | Parte 9 |
| Controle direcional de tráfego | Parte 10 |

---

## Próximos passos

Em aulas futuras:

* VPN site-a-site com pfSense (OpenVPN ou WireGuard)
* Introdução ao roteamento dinâmico (OSPF)
