# 🧪 Laboratório 01 — Introdução ao GNS3 com Docker e Open vSwitch

## 🎯 Objetivo

Este laboratório tem como objetivo introduzir o uso do GNS3 e conceitos básicos de redes de computadores utilizando containers Docker e um switch baseado em Open vSwitch.

Ao final, o aluno será capaz de:

* Criar e conectar dispositivos no GNS3
* Configurar endereçamento IP em hosts Linux
* Testar conectividade com `ping`
* Entender o funcionamento de um switch
* Observar ARP e tabela MAC em tempo real
* Diagnosticar problemas de conectividade em camadas
* Implementar e validar VLANs básicas

---

## ⏱️ Duração estimada

Aproximadamente **2h30**

---

## 🧱 Pré-requisitos

* GNS3 instalado e configurado
* Acesso a um servidor GNS3 remoto
* Templates disponíveis:
  * Container: `ubuntu-net` (com ferramentas de rede)
  * Switch: Open vSwitch (OVS)

---

## 🧪 Parte 1 — Conectividade básica

### 🎯 Objetivo

Configurar endereçamento IP e testar comunicação entre múltiplos hosts conectados ao mesmo switch.

---

### 🖥️ Topologia

```
PC1 ----+
        |
PC2 ----+---- SWITCH (OVS)
        |
PC3 ----+
        |
PC4 ----+
```

---

### 🛠️ Passos

1. Adicione ao projeto:
   * 4 containers Ubuntu (`PC1`, `PC2`, `PC3`, `PC4`)
   * 1 switch OVS

2. Conecte:
   * PC1 → `eth1` do switch
   * PC2 → `eth2` do switch
   * PC3 → `eth3` do switch
   * PC4 → `eth4` do switch

> ⚠️ **Nunca utilizar `eth0` do switch**

---

### ⚙️ Configuração dos hosts

#### PC1

```bash
ip addr add 10.0.0.1/24 dev eth0
ip link set eth0 up
```

#### PC2

```bash
ip addr add 10.0.0.2/24 dev eth0
ip link set eth0 up
```

#### PC3

```bash
ip addr add 10.0.0.3/24 dev eth0
ip link set eth0 up
```

#### PC4

```bash
ip addr add 10.0.0.4/24 dev eth0
ip link set eth0 up
```

---

### 🧪 Testes

Em cada host, teste a comunicação com os demais:

```bash
ping -c 3 10.0.0.2
ping -c 3 10.0.0.3
ping -c 3 10.0.0.4
```

> 💡 Realize os testes nos **dois sentidos** para garantir comunicação bidirecional.

---

### 💬 Perguntas

* Por que não foi necessário configurar gateway?
* Qual é a função do switch nessa topologia?
* O que acontece quando um host envia um pacote para um IP que ainda não conhece?

---

## 🧪 Parte 2 — Observando a rede em tempo real

### 🎯 Objetivo

Entender o funcionamento do ARP e o aprendizado de endereços MAC pelo switch, observando o comportamento **antes e depois** da comunicação.

---

### 🔍 Passo 1 — Estado inicial (antes do ping)

No switch, verifique a tabela MAC **antes** de qualquer comunicação:

```bash
ovs-appctl fdb/show br0
```

> 📝 A tabela deve estar **vazia** ou com poucas entradas. Anote o resultado.

Nos hosts, verifique o cache ARP:

```bash
arp -n
```

> 📝 Também deve estar **vazio**. Anote o resultado.

---

### 🔍 Passo 2 — Gerar tráfego

No PC1, execute:

```bash
ping -c 3 10.0.0.2
ping -c 3 10.0.0.3
ping -c 3 10.0.0.4
```

---

### 🔍 Passo 3 — Estado após o ping

Repita as verificações:

```bash
# No switch
ovs-appctl fdb/show br0

# Nos hosts
arp -n
```

> 📝 Compare com os resultados anteriores. O que mudou?

---

### 🧪 Captura de pacotes

> ⚠️ **Importante:** No Open vSwitch, o tráfego não passa pela interface `br0` como em bridges tradicionais. O comando abaixo pode **não mostrar nenhum pacote**, mesmo com a rede funcionando:

```bash
tcpdump -i br0
```

👉 Para capturar corretamente, utilize as interfaces conectadas ao switch:

```bash
tcpdump -i eth1
```

Ou para capturar em todas as interfaces:

```bash
tcpdump -i any
```

Para filtrar apenas tráfego ARP:

```bash
tcpdump -i eth1 arp
```

> 💡 Abra dois terminais: em um execute o `tcpdump`, no outro execute o `ping`. Observe os pacotes ARP aparecerem em tempo real.

---

### 💬 Perguntas

* O que é ARP e por que ele é necessário?
* Em que momento o switch aprende os endereços MAC?
* Por que `tcpdump -i br0` pode não mostrar tráfego no OVS?
* Quantas entradas apareceram na tabela MAC após os pings? Por quê?

---

## 🧪 Parte 3 — Troubleshooting em camadas

### 🎯 Objetivo

Identificar e diagnosticar problemas de conectividade simulando falhas em diferentes camadas (L1, L2 e L3).

---

### ❌ Cenário A — Problema na Camada 3 (endereço IP incorreto)

No PC2, configure um IP em uma rede diferente:

```bash
ip addr flush dev eth0
ip addr add 10.0.1.2/24 dev eth0
ip link set eth0 up
```

Tente comunicar a partir do PC1:

```bash
ping -c 3 10.0.0.2
```

**Diagnóstico:**

```bash
# Verifique o IP configurado
ip addr show eth0

# Verifique se há entrada ARP
arp -n
```

> 💬 **Perguntas:**
> * Por que a comunicação falhou?
> * O switch tem alguma responsabilidade nessa falha?
> * Como você identificou o problema?

---

### ❌ Cenário B — Problema na Camada 1 (interface down)

Restaure o IP correto no PC2 e depois derrube a interface:

```bash
ip addr flush dev eth0
ip addr add 10.0.0.2/24 dev eth0
ip link set eth0 down
```

Tente comunicar a partir do PC1:

```bash
ping -c 3 10.0.0.2
```

**Diagnóstico:**

```bash
# Verifique o estado da interface
ip link show eth0

# Verifique a tabela MAC no switch
ovs-appctl fdb/show br0
```

> 💬 **Perguntas:**
> * Qual a diferença entre esse erro e o do Cenário A?
> * Como o estado da interface aparece no comando `ip link show`?
> * O endereço MAC do PC2 ainda aparece na tabela do switch?

---

### ❌ Cenário C — Problema na Camada 3 (IP removido)

Restaure a interface e remova o IP:

```bash
ip link set eth0 up
ip addr flush dev eth0
```

Tente comunicar a partir do PC1:

```bash
ping -c 3 10.0.0.2
```

**Diagnóstico:**

```bash
ip addr show eth0
```

> 💬 **Perguntas:**
> * Por que a comunicação falhou desta vez?
> * Como restaurar a conectividade?

---

### ✅ Restauração

Ao final, restaure todos os hosts para o estado correto antes de prosseguir:

```bash
ip addr flush dev eth0
ip addr add 10.0.0.X/24 dev eth0   # substitua X pelo número do host
ip link set eth0 up
```

---

## 🧪 Parte 4 — VLANs: isolamento e validação

### 🎯 Objetivo

Implementar VLANs para isolar grupos de hosts e validar o isolamento com testes em ambos os sentidos.

---

### 📖 Contexto

> *"A empresa possui dois setores: **TI** e **Financeiro**. Por um erro de configuração, todos os computadores estão na mesma VLAN e podem se comunicar livremente. Sua tarefa é separar os setores e confirmar o isolamento."*

---

### 🖥️ Topologia

```
PC1 (TI)         ----+
                     |
PC2 (TI)         ----+---- SWITCH (OVS)
                     |
PC3 (Financeiro) ----+
                     |
PC4 (Financeiro) ----+
```

| Host | Setor      | IP          | VLAN |
|------|------------|-------------|------|
| PC1  | TI         | 10.0.0.1/24 | 10   |
| PC2  | TI         | 10.0.0.2/24 | 10   |
| PC3  | Financeiro | 10.0.0.3/24 | 20   |
| PC4  | Financeiro | 10.0.0.4/24 | 20   |

---

### ⚙️ Configuração no switch

#### VLAN 10 — Setor de TI (PC1 e PC2)

```bash
ovs-vsctl set port eth1 tag=10
ovs-vsctl set port eth2 tag=10
```

#### VLAN 20 — Setor Financeiro (PC3 e PC4)

```bash
ovs-vsctl set port eth3 tag=20
ovs-vsctl set port eth4 tag=20
```

---

### 🧪 Testes de validação

#### ✅ Comunicação esperada (mesma VLAN)

```bash
# PC1 → PC2 (VLAN 10): deve funcionar
ping -c 3 10.0.0.2

# PC3 → PC4 (VLAN 20): deve funcionar
ping -c 3 10.0.0.4
```

#### ❌ Comunicação bloqueada (VLANs diferentes)

```bash
# PC1 → PC3 (VLAN 10 → VLAN 20): NÃO deve funcionar
ping -c 3 10.0.0.3

# PC2 → PC4 (VLAN 10 → VLAN 20): NÃO deve funcionar
ping -c 3 10.0.0.4

# PC3 → PC1 (VLAN 20 → VLAN 10): NÃO deve funcionar
ping -c 3 10.0.0.1
```

> 💡 Teste **sempre nos dois sentidos** para confirmar o isolamento completo.

---

### 🔍 Verificação das VLANs no switch

```bash
ovs-vsctl show
```

> 📝 Observe as tags configuradas em cada porta.

---

### 💬 Perguntas

* O que é uma VLAN e por que ela é útil em ambientes corporativos?
* Por que hosts com IPs na mesma sub-rede não conseguem se comunicar quando estão em VLANs diferentes?
* O switch precisa "saber" sobre IPs para implementar VLANs?

---

## 🧪 Parte 5 — Desafio final

### 🎯 Objetivo

Aplicar todos os conceitos aprendidos para resolver um problema de rede.

---

### 🧩 Cenário

> *"O gerente de TI informou que PC1 precisa se comunicar com PC3 para acessar um sistema do setor Financeiro. Atualmente, a comunicação está bloqueada pelas VLANs. Reconfigure a rede para que isso seja possível, **sem remover o isolamento entre os demais hosts**."*

---

### 📋 Requisitos

* PC1 deve conseguir se comunicar com PC3
* PC2 **não** deve conseguir se comunicar com PC3 ou PC4
* PC4 **não** deve conseguir se comunicar com PC1 ou PC2

---

### 💡 Dicas

* Verifique as VLANs configuradas em cada porta
* Pense em qual VLAN PC1 e PC3 precisam estar
* Lembre-se de testar **todos os pares** após a reconfiguração

---

### 🔍 Comandos úteis para revisão

```bash
# Ver configuração atual do switch
ovs-vsctl show

# Ver tabela MAC
ovs-appctl fdb/show br0

# Ver IPs dos hosts
ip addr show eth0

# Remover tag de uma porta (se necessário)
ovs-vsctl remove port eth1 tag 10
```

---

## 📘 Entregável

Cada aluno deve entregar:

* Print da topologia montada no GNS3
* Prints dos testes de ping (funcionando e bloqueados)
* Print da tabela MAC antes e depois do ping (Parte 2)
* Comandos utilizados no desafio final
* Respostas às perguntas de cada parte

---

## 🧠 Conceitos abordados

| Conceito           | Onde foi abordado         |
|--------------------|---------------------------|
| Endereçamento IP   | Partes 1, 3               |
| Switch L2          | Partes 1, 2               |
| ARP                | Parte 2                   |
| Tabela MAC         | Parte 2                   |
| Troubleshooting L1 | Parte 3 — Cenário B       |
| Troubleshooting L3 | Parte 3 — Cenários A e C  |
| VLAN               | Parte 4                   |
| Validação de rede  | Partes 4 e 5              |

---

## 🚀 Próximos passos

Em aulas futuras:

* VLAN trunk
* Roteamento entre VLANs (inter-VLAN routing)
* NAT e firewall
* Simulação de redes reais

---

## ⚠️ Observações importantes

* Não utilizar `eth0` no switch OVS
* Sempre configurar IP com máscara (`/24`)
* Realizar testes nos **dois sentidos** (`ping`)
* Em OVS, usar `tcpdump` nas interfaces (`ethX`), não em `br0`
* Ao remover IPs com `ip addr flush`, **todos** os endereços da interface são removidos
* Sempre restaurar a configuração correta antes de avançar para a próxima parte

---

## ✅ Conclusão

Este laboratório fornece uma base sólida para:

* Uso prático do GNS3 com Docker
* Conceitos fundamentais de redes L2
* Diagnóstico de problemas em múltiplas camadas
* Implementação e validação de VLANs

---

🎯 **Você agora está pronto para evoluir para cenários mais avançados.**
