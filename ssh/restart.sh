#!/bin/bash
# Restart only services that actually exist on this installation.
clear
echo "Starting Restart All Service"

restart_unit() {
    local unit="$1"
    if systemctl cat "$unit" >/dev/null 2>&1; then
        systemctl restart "$unit" >/dev/null 2>&1 && echo "Restarted $unit" || echo "FAILED $unit"
    fi
}

restart_init() {
    local script="$1"
    if [ -x "$script" ]; then
        "$script" restart >/dev/null 2>&1 && echo "Restarted $script" || echo "FAILED $script"
    fi
}

for unit in \
    ssrmu ws-tls ws-nontls xray.service shadowsocks-libev xl2tpd pptpd ipsec \
    accel-ppp ws-ovpn wg-quick@wg0 ssh-ohp dropbear-ohp openvpn-ohp trojan-go \
    stunnel5 fail2ban cron squid vnstat; do
    restart_unit "$unit"
done

restart_init /etc/init.d/ssrmu
restart_init /etc/init.d/ssh
restart_init /etc/init.d/dropbear
restart_init /etc/init.d/openvpn

if command -v nginx >/dev/null 2>&1; then
    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx >/dev/null 2>&1 || true
        echo "Restarted nginx"
    else
        echo "SKIPPED nginx: configuration test failed"
    fi
fi

if command -v badvpn-udpgw >/dev/null 2>&1; then
    for port in 7100 7200 7300; do
        screen -S "badvpn-$port" -X quit >/dev/null 2>&1 || true
        screen -dmS "badvpn-$port" badvpn-udpgw --listen-addr "127.0.0.1:$port" --max-clients 1000
    done
fi

echo "Restart All Service Complete"
