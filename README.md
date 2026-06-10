# network-observability-stack

SNMP-based observability stack for network devices (Cisco, Juniper or any
SNMP-capable gear) built with **Prometheus**, **snmp_exporter**,
**Alertmanager** and **Grafana** — fully provisioned, up with one command.

```
docker compose up -d
```

| Service | URL | Purpose |
|---------|-----|---------|
| Grafana | http://localhost:3000 | Dashboards (auto-provisioned) |
| Prometheus | http://localhost:9090 | Metrics, alert rules |
| Alertmanager | http://localhost:9093 | Alert routing |
| snmp_exporter | http://localhost:9116 | SNMP → Prometheus bridge |

## What you get out of the box

- **Interface metrics** for every device listed in
  `prometheus/prometheus.yml` (job `snmp-network-devices`), polled through
  the snmp_exporter `if_mib` module: traffic, errors, discards, oper status.
- **Grafana dashboard** "Network / Interfaces (SNMP)" with a device
  selector: devices up/down, interfaces oper-down, in/out traffic, errors
  and discards.
- **Alert rules** (`prometheus/rules/network_alerts.yml`):
  - `DeviceUnreachable` — SNMP polling failing for 5 min (critical)
  - `InterfaceDown` — admin up but oper down for 5 min
  - `InterfaceHighUtilization` — above 90% of link speed for 15 min
  - `InterfaceErrorsIncreasing` — sustained input errors

## Quick start

```bash
cp .env.example .env          # set the Grafana admin password
# Edit prometheus/prometheus.yml: replace the sample 192.0.2.x targets
# with your devices' management IPs
docker compose up -d
```

Devices must have SNMP v2c enabled with the `public` community (the
exporter's default `public_v2` auth). Examples:

```
! Cisco IOS
snmp-server community public RO

# Junos
set snmp community public authorization read-only
```

To use a different community or SNMPv3, generate a custom `snmp.yml` with
the [snmp_exporter generator](https://github.com/prometheus/snmp_exporter/tree/main/generator)
and mount it over `/etc/snmp_exporter/snmp.yml` in the `snmp-exporter`
service.

## Alert delivery

`alertmanager/alertmanager.yml` ships with a placeholder receiver. Point it
at Slack, Microsoft Teams, e-mail or a webhook — the file contains a
commented Slack example.

## Layout

```
docker-compose.yml
prometheus/
├── prometheus.yml            # scrape configs (SNMP relabel pattern)
└── rules/network_alerts.yml  # alerting rules
alertmanager/alertmanager.yml
grafana/
├── provisioning/             # datasource + dashboard providers
└── dashboards/               # dashboard JSON (auto-loaded)
```

## Roadmap

- gNMI/streaming telemetry pipeline (telegraf → Prometheus) for IOS-XR/Junos
- Per-platform dashboards (CPU/memory via vendor MIBs, BGP session state)
- syslog ingestion with Loki

## License

MIT
