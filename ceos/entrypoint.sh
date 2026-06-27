#!/bin/bash
# Loop em background que reabre o iptables a cada 10s
# O Acl agent do EOS regenera as regras periodicamente, então precisamos manter
while true; do
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    sleep 10
done &
exec /sbin/init "$@"
