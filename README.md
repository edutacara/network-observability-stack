# network-observability-stack

Stack de observabilidade SNMP com **Prometheus**, **snmp_exporter**,
**Alertmanager** e **Grafana**, usando dois switches Arista cEOS-lab em peering
BGP para simular um ambiente de rede real sem hardware físico.

## Serviços

| Serviço | URL / porta | Função |
|---------|-------------|--------|
| Grafana | http://localhost:3000 | Dashboards (auto-provisionados) |
| Prometheus | http://localhost:9090 | Métricas e regras de alerta |
| Alertmanager | http://localhost:9093 | Roteamento de alertas |
| snmp_exporter | http://localhost:9116 | Bridge SNMP → Prometheus |
| ceos1 SSH | `ssh admin@localhost -p 2222` | CLI Arista cEOS-lab 1 |
| ceos2 SSH | `ssh admin@localhost -p 2223` | CLI Arista cEOS-lab 2 |

## Topologia

```
                  ┌────────────────────────────┐
                  │   Docker network: monitoring │
                  │        172.20.0.0/24         │
                  │                              │
  172.20.0.10 ┌──┴──┐         ┌──────┐          │
   ceos1 ──── │eth0 │         │eth0  │ 172.20.0.20
              └──┬──┘         └──┬───┘ ceos2
                 │               │
                 │  peering net  │
                 │  10.0.0.0/29  │
         eth1 ──┤ 10.0.0.2      │ 10.0.0.3 ──eth1
    (Ethernet1) │  BGP AS65001  │ BGP AS65002  (Ethernet1)
                └───────────────┘
```

## Quick start

### 1. Importar a imagem do Arista cEOS-lab

Faça download de `cEOS-lab-4.36.1F.tar` em
[arista.com/en/support/software-download](https://www.arista.com/en/support/software-download):

```bash
docker import ~/Downloads/cEOS-lab-4.36.1F.tar ceos:4.36.1F
```

### 2. Subir o stack

```bash
docker compose up -d
```

O cEOS demora ~60-90 s para inicializar completamente. Acompanhe com:

```bash
docker logs -f ceos1
```

### 3. Acessar os switches via SSH

```bash
ssh admin@localhost -p 2222   # ceos1
ssh admin@localhost -p 2223   # ceos2
# senha: admin
```

### 4. Verificar peering BGP

```
ceos1# show bgp summary
Neighbor   AS       MsgRcvd  MsgSent  InQ  OutQ  Up/Down   State/PfxRcd
10.0.0.3   65002    ...      ...      0    0     00:xx:xx  1
```

## O que está incluído

### Métricas coletadas (SNMP)

| Módulo | MIB | Métricas |
|--------|-----|----------|
| `if_mib` | IF-MIB | Tráfego, erros, discards, status operacional |
| `bgp4_mib` | BGP4-MIB (RFC 4273) | Estado FSM dos peers, contadores de mensagens e updates |
| `ospf_mib` | OSPF-MIB (RFC 1850) | Estado das adjacências |

### Dashboards Grafana

- **Network / Interfaces (SNMP)** — seletor de dispositivo, interfaces down, tráfego in/out, erros e discards
- **Network / BGP Sessions (SNMP)** — estado dos peers (mapeamento Idle→Established), session uptime, flaps, taxa de mensagens e updates

### Regras de alerta

| Alerta | Condição | Severidade |
|--------|----------|-----------|
| `DeviceUnreachable` | Falha no polling SNMP por 5 min | critical |
| `InterfaceDown` | Admin up, oper down por 5 min | warning |
| `InterfaceHighUtilization` | Utilização > 90% por 15 min | warning |
| `InterfaceErrorsIncreasing` | Erros de entrada crescentes | warning |

## Arista cEOS-lab — detalhes

### Variáveis de ambiente obrigatórias (cEOS 4.36.1F)

| Variável | Valor | Motivo |
|----------|-------|--------|
| `MGMT_INTF` | `eth0` | Mapeia `eth0` → `Management0` no EOS; sem isso eth0 é descartado silenciosamente |
| `EOS_PLATFORM` | `ceoslab` | Ativa o `cEOSLabDriver` |
| `INTFTYPE` | `eth` | Prefixo dos dispositivos de kernel reconhecidos |

### iptables

O agente Acl do EOS regera as regras de iptables de forma programática. Para manter INPUT/OUTPUT policy em `ACCEPT`, o `entrypoint.sh` executa um loop em background que reaplica as políticas a cada 10 s antes de chamar `/sbin/init`.

### Configuração BGP

| Router | AS | Router-ID | Peer IP | Peer AS |
|--------|----|-----------|---------|---------|
| ceos1 | 65001 | 1.1.1.1 | 10.0.0.3 | 65002 |
| ceos2 | 65002 | 2.2.2.2 | 10.0.0.2 | 65001 |

Ambos anunciam o prefixo `10.0.0.0/29` (link de peering).

### BGP4-MIB — valores de bgpPeerState

| Valor | Estado |
|-------|--------|
| 1 | Idle |
| 2 | Connect |
| 3 | Active |
| 4 | OpenSent |
| 5 | OpenConfirm |
| 6 | Established |

## Adicionar dispositivos reais

Edite `prometheus/prometheus.yml` e inclua os IPs de gerência nos jobs
`snmp-network-devices`, `snmp-bgp` e `snmp-ospf`. Os dispositivos devem
aceitar SNMP v2c com community `public`:

```
! Arista EOS
snmp-server community public ro

! Cisco IOS
snmp-server community public RO

# Junos
set snmp community public authorization read-only
```

Para community diferente ou SNMPv3, gere um `snmp.yml` customizado com o
[snmp_exporter generator](https://github.com/prometheus/snmp_exporter/tree/main/generator).

## Alert delivery

Configure `alertmanager/alertmanager.yml` com o receiver desejado (Slack,
Teams, e-mail ou webhook). O arquivo contém um exemplo comentado para Slack.

## Layout

```
docker-compose.yml
.env.example
ceos/
├── startup-config          # Config inicial do ceos1 (SNMP, SSH, BGP AS65001)
├── startup-config-ceos2    # Config inicial do ceos2 (SNMP, SSH, BGP AS65002)
└── entrypoint.sh           # Mantém iptables aberto + exec /sbin/init
prometheus/
├── prometheus.yml          # Jobs: snmp-network-devices, snmp-bgp, snmp-ospf
└── rules/
    └── network_alerts.yml  # Alertas de dispositivo, interface e utilização
alertmanager/
└── alertmanager.yml
grafana/
├── provisioning/           # Datasource + dashboard providers
└── dashboards/
    ├── network-interfaces.json   # Dashboard de interfaces
    └── bgp-sessions.json         # Dashboard BGP
snmp/
└── snmp.yml                # Módulos SNMP (if_mib, bgp4_mib, ospf_mib)
```

## Roadmap

- gNMI/streaming telemetry (Telegraf → Prometheus) para IOS-XR / Junos
- Dashboard de CPU/memória via vendor MIBs
- Ingestão de syslog com Loki

## License

MIT
