# 🧪 Atividade 12 — Avaliação Final: Interligação Matriz-Filial

## Contexto

A empresa **TechSul** precisa conectar sua sede (Matriz) a uma filial remota. A equipe de TI foi encarregada de montar a infraestrutura de rede usando os recursos disponíveis no laboratório.

Na **Matriz**, existem duas redes internas separadas por VLAN:
- **VLAN 10 — TI**: equipe técnica, acesso irrestrito
- **VLAN 20 — Gestão**: equipe administrativa, com restrições de acesso

A **Filial** possui uma rede única de usuários. Ela não tem acesso direto à Internet — o tráfego externo deve ser roteado pela Matriz.

**Requisito de segurança:** a equipe de Gestão (VLAN 20) não deve ter acesso direto à rede interna da Filial. A equipe de TI deve poder acessar todos os destinos sem restrições.

---

## Duração

Aproximadamente **2 horas** (atividade individual ou em dupla)

---

## Topologia

```
              [ NAT do GNS3 ]
                     │
                  ether1
                [GW-Matriz]──────────── [OVS-Matriz] ──── PC-TI   (VLAN 10)
                     │    ether2 (trunk)                └── PC-Gestão (VLAN 20)
                  ether3
              10.0.0.0/30 (enlace WAN)
                  ether1
                [GW-Filial]
                  ether2
               [OVS-Filial]
                     │
                 PC-Filial
```

---

## Tabela de endereçamento

| Dispositivo | Interface | Endereço IP | Observação |
|-------------|-----------|-------------|------------|
| GW-Matriz | ether1 | DHCP via NAT | Saída Internet |
| GW-Matriz | ether2 | — | Porta trunk (sem IP) |
| GW-Matriz | vlan10 | 10.10.10.1/24 | Gateway VLAN 10 — TI |
| GW-Matriz | vlan20 | 10.10.20.1/24 | Gateway VLAN 20 — Gestão |
| GW-Matriz | ether3 | 10.0.0.1/30 | Enlace WAN para Filial |
| GW-Filial | ether1 | 10.0.0.2/30 | Enlace WAN para Matriz |
| GW-Filial | ether2 | 192.168.100.1/24 | Gateway LAN Filial |
| PC-TI | eth0 | 10.10.10.100–200 | DHCP — VLAN 10 |
| PC-Gestão | eth0 | 10.10.20.100–200 | DHCP — VLAN 20 |
| PC-Filial | eth0 | 192.168.100.100–200 | DHCP — LAN Filial |

---

## Conexões no GNS3

| De | Porta | Para | Porta |
|----|-------|------|-------|
| NAT | — | GW-Matriz | e0 (ether1) |
| GW-Matriz | e1 (ether2) | OVS-Matriz | eth1 |
| GW-Matriz | e2 (ether3) | GW-Filial | e0 (ether1) |
| OVS-Matriz | eth2 | PC-TI | eth0 |
| OVS-Matriz | eth3 | PC-Gestão | eth0 |
| GW-Filial | e1 (ether2) | OVS-Filial | eth1 |
| OVS-Filial | eth2 | PC-Filial | eth0 |

---

## Requisitos

A rede deve satisfazer **todos** os itens abaixo:

1. **Endereçamento:** todos os roteadores e hosts devem ter endereço IP configurado conforme a tabela acima.

2. **DHCP na Matriz:** PC-TI deve receber IP automaticamente na faixa `10.10.10.100–200`; PC-Gestão deve receber IP automaticamente na faixa `10.10.20.100–200`.

3. **DHCP na Filial:** PC-Filial deve receber IP automaticamente na faixa `192.168.100.100–200`.

4. **NAT na Matriz:** PC-TI e PC-Gestão devem conseguir pingar `8.8.8.8` (Internet via Matriz).

5. **Conectividade no enlace WAN:** GW-Matriz deve conseguir pingar GW-Filial (`10.0.0.2`) e vice-versa.

6. **Roteamento dinâmico (OSPF):** GW-Matriz e GW-Filial devem formar adjacência OSPF no estado `Full`. Todas as redes internas (VLANs e LAN Filial) devem aparecer na tabela de rotas de ambos os roteadores.

7. **Acesso da Filial às redes da Matriz:** PC-Filial deve conseguir pingar PC-TI (`10.10.10.x`) e PC-Gestão (`10.10.20.x`).

8. **Acesso à Internet pela Filial:** PC-Filial deve conseguir pingar `8.8.8.8` usando a saída de Internet da Matriz (confirmado por traceroute passando por GW-Matriz).

9. **Restrição de firewall:** PC-Gestão **não** deve conseguir pingar PC-Filial (`192.168.100.x`). PC-TI deve continuar com acesso irrestrito a PC-Filial.

10. **Medição de desempenho:** executar um teste iPerf entre PC-TI e PC-Filial e registrar a largura de banda medida.

---

## Dicas

* Revise a configuração de VLANs como sub-interfaces no MikroTik → **Atividade 10, Parte 2**
* Revise a configuração de trunk no OVS → **Atividade 10, Parte 2**
* Revise DHCP server e NAT no MikroTik → **Atividade 10, Parte 1**
* Revise OSPF: instância, área, interface-templates → **Atividade 11, Parte 1**
* Revise redistribuição de rota padrão via OSPF → **Atividade 11, Pré-configuração**
* Revise regras de firewall `chain=forward` → **Atividade 10, Parte 3**
* Revise iPerf → **Atividade 11, Parte 5**

---

## Entregáveis

Entregue capturas de tela comprovando cada requisito:

| # | Evidência exigida |
|---|-------------------|
| 1 | Print da topologia montada no GNS3 com todos os nós e cabos |
| 2 | `/ip address print` e `/ip dhcp-server print` do GW-Matriz |
| 3 | `ip addr show eth0` de PC-TI e PC-Gestão mostrando IPs nas faixas corretas |
| 4 | `ip addr show eth0` e `ip route` de PC-Filial |
| 5 | `ping -c 3 8.8.8.8` executado a partir de PC-TI **e** de PC-Filial |
| 6 | `/routing ospf neighbor print` do GW-Matriz mostrando estado `Full` |
| 7 | `/ip route print where protocol=ospf` do GW-Filial mostrando rotas aprendidas (incluindo `0.0.0.0/0`) |
| 8 | `ping -c 3 10.10.10.x` e `ping -c 3 10.10.20.x` executados de PC-Filial |
| 9 | `ping -c 3 192.168.100.x` de PC-Gestão (**sem resposta**) e de PC-TI (**com resposta**) |
| 10 | Output do `iperf3` entre PC-TI (cliente) e PC-Filial (servidor) |

---

---

# Guia de Correção — Professor

> Este guia destina-se exclusivamente ao professor. Os itens e comandos abaixo permitem verificar objetivamente cada requisito da avaliação.

---

## Rubrica (2,0 pontos)

| Item | Descrição | Pontos |
|------|-----------|--------|
| R1 | Topologia montada corretamente no GNS3 | 0,2 |
| R2 | VLANs na Matriz com DHCP funcionando (0,1 por VLAN) | 0,2 |
| R3 | DHCP na Filial funcionando | 0,1 |
| R4 | NAT e acesso à Internet de PC-TI | 0,2 |
| R5 | Conectividade no enlace WAN (10.0.0.0/30) | 0,1 |
| R6 | Adjacência OSPF Full entre os roteadores | 0,2 |
| R7 | Rotas OSPF corretas em ambos os roteadores (incluindo default) | 0,2 |
| R8 | PC-Filial alcança ambas as VLANs da Matriz | 0,2 |
| R9 | Regra de firewall correta (Gestão bloqueada, TI livre) | 0,3 |
| R10 | iPerf executado com resultado registrado | 0,1 |
| **Total** | | **2,0** |

---

## Verificação por item

### R1 — Topologia (0,2 pts)

Verificação visual no GNS3. Checar:
- 2 roteadores MikroTik, 2 switches OVS, 3 hosts ubuntu-net, 1 NAT cloud
- Cabos conforme a tabela de conexões do enunciado

**Erro comum:** conectar PC-TI e PC-Gestão nas portas erradas do OVS (inversão de VLAN).

---

### R2 — VLANs na Matriz com DHCP (0,2 pts)

No console de **GW-Matriz**:

```
/interface print
/ip address print
/ip dhcp-server print
/ip dhcp-server lease print
```

Esperado:
- Interfaces `vlan10` e `vlan20` listadas
- `10.10.10.1/24` em vlan10, `10.10.20.1/24` em vlan20
- Dois servidores DHCP ativos (um por VLAN)
- Leases para PC-TI (10.10.10.x) e PC-Gestão (10.10.20.x)

No OVS-Matriz:

```bash
ovs-vsctl show
```

Esperado:
- `eth1` configurado com `trunks: [10, 20]`
- `eth2` com `tag: 10`, `eth3` com `tag: 20`

**Erro comum:** OVS sem configuração de trunk (eth1 sem trunks) → hosts recebem IP, mas pacotes não chegam ao MikroTik taggeados; DHCP falha ou entrega IP errado.

---

### R3 — DHCP na Filial (0,1 pts)

No console de **GW-Filial**:

```
/ip dhcp-server print
/ip dhcp-server lease print
```

No terminal de **PC-Filial**:

```bash
ip addr show eth0
```

Esperado: IP na faixa `192.168.100.100–200`, gateway `192.168.100.1`.

---

### R4 — NAT e Internet (0,2 pts)

No console de **GW-Matriz**:

```
/ip firewall nat print
/ip dhcp-client print
```

Esperado:
- Regra de masquerade com `chain=srcnat`, `out-interface=ether1`, `action=masquerade`
- ether1 com status `bound`

De **PC-TI**:

```bash
ping -c 3 8.8.8.8
```

Deve responder.

**Erro comum:** NAT configurado em `out-interface=ether2` ou `ether3` em vez de `ether1`.

---

### R5 — Enlace WAN (0,1 pts)

No console de **GW-Matriz**:

```
ping 10.0.0.2
```

No console de **GW-Filial**:

```
ping 10.0.0.1
```

Ambos devem responder. Se não responder, o OSPF não formará adjacência.

**Erro comum:** endereços /30 invertidos (estudante coloca `.1` na Filial e `.2` na Matriz).

---

### R6 — Adjacência OSPF Full (0,2 pts)

No console de **GW-Matriz**:

```
/routing ospf neighbor print
```

Esperado: uma entrada com `ADDRESS=10.0.0.2`, `STATE=Full/PtP`.

No console de **GW-Filial**:

```
/routing ospf neighbor print
```

Esperado: uma entrada com `ADDRESS=10.0.0.1`, `STATE=Full/PtP`.

**Erro comum 1:** estudante configura `type=broadcast` em vez de `type=ptp` no enlace WAN — a adjacência pode travar em `2-Way` por causa da eleição de DR/BDR.

**Erro comum 2:** estudante adiciona o enlace WAN ao OSPF em apenas um dos roteadores — adjacência nunca é formada.

**Erro comum 3:** estudante não cria a instância OSPF ou cria em apenas um roteador.

---

### R7 — Rotas OSPF corretas (0,2 pts)

No console de **GW-Matriz**:

```
/ip route print where protocol=ospf
```

Esperado: rota para `192.168.100.0/24` via `10.0.0.2`.

No console de **GW-Filial**:

```
/ip route print where protocol=ospf
```

Esperado:
- `10.10.10.0/24` via `10.0.0.1`
- `10.10.20.0/24` via `10.0.0.1`
- `0.0.0.0/0` via `10.0.0.1` (rota padrão redistribuída)

Para a rota padrão aparecer, GW-Matriz precisa ter configurado:

```
/routing ospf instance set default originate-default=always
```

**Erro comum:** estudante não redistribui a rota padrão — PC-Filial chega às VLANs da Matriz mas não acessa a Internet.

---

### R8 — PC-Filial alcança VLANs da Matriz (0,2 pts)

De **PC-Filial**:

```bash
ping -c 3 10.10.10.1     # gateway VLAN 10
ping -c 3 10.10.20.1     # gateway VLAN 20
ping -c 3 <IP de PC-TI>
ping -c 3 <IP de PC-Gestão>
```

Todos devem responder (antes da regra de firewall ser aplicada — ou verificar que PC-TI ainda responde depois).

---

### R9 — Regra de firewall (0,3 pts)

No console de **GW-Matriz**:

```
/ip firewall filter print
```

Regra esperada:

```
chain=forward   in-interface=vlan20   out-interface=ether3   action=drop
```

Ou equivalentemente com `dst-address=192.168.100.0/24`.

**Teste 1 — Bloqueio:** de **PC-Gestão**:

```bash
ping -c 3 192.168.100.1
```

Deve **falhar** (100% packet loss ou `Destination Host Unreachable`).

**Teste 2 — TI livre:** de **PC-TI**:

```bash
ping -c 3 192.168.100.1
```

Deve **funcionar**.

**Erro comum 1:** estudante usa `chain=input` em vez de `chain=forward` — a regra afeta tráfego destinado ao próprio roteador, não o tráfego passante.

**Erro comum 2:** estudante bloqueia `in-interface=vlan20 out-interface=vlan10` — bloqueia tráfego entre VLANs na Matriz, não o acesso à Filial.

**Erro comum 3:** estudante usa `action=reject` — o comportamento visível é diferente mas o requisito de bloqueio é atendido; aceitar com desconto mínimo.

---

### R10 — iPerf (0,1 pts)

Em **PC-Filial** (servidor):

```bash
iperf3 -s
```

Em **PC-TI** (cliente):

```bash
iperf3 -c <IP de PC-Filial> -t 20
```

O estudante deve apresentar o output mostrando a largura de banda medida. Qualquer valor numérico positivo é suficiente para pontuar.

**Observação:** iperf3 precisa ser instalado (`apt-get install -y iperf3`). Se o estudante não conseguiu instalar por falta de acesso à Internet (R4 não resolvido), este item não pode ser avaliado — não descontar R10 se a razão for falha em R4.

---

## Critérios gerais de avaliação

* Cada item é avaliado com base na evidência apresentada (print) **e** na verificação ao vivo no GNS3, se disponível.
* Configurações que funcionam mas usam endereços fora da tabela do enunciado devem receber **desconto de 50%** no item correspondente.
* Itens que dependem de itens anteriores não resolvidos (ex.: R8 depende de R6 e R7) não são penalizados duplamente — pontuar o item mais avançado se a cadeia de dependências estiver completa.
* iPerf (R10) não é descontado se a falha for causada exclusivamente por R4 não resolvido.
