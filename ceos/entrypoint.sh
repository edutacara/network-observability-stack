#!/bin/bash
# Mantém iptables INPUT/OUTPUT aberto (Acl agent regenera as regras periodicamente)
while true; do
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    sleep 10
done &

# Habilita gNMI assim que o EOS aceitar config (Cli -p 15 retorna 0 ao estar pronto)
(
    until echo -e "show version\n" | Cli -p 15 2>/dev/null | grep -q "cEOS"; do
        sleep 10
    done
    echo -e "configure\nmanagement api gnmi\ntransport grpc default\nno shutdown\nend\n" | Cli -p 15 2>/dev/null
) &

exec /sbin/init "$@"
