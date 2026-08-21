#!/bin/bash
# MAHBOUB VPS - Central Service Port Settings
# Uses the existing service configuration on this VPS.

RED='\033[0;31m'; NC='\033[0m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; WHITE='\033[0;37m'

pause(){ read -r -p "Press Enter to continue..." _; }
valid_port(){ [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }
port_busy(){ ss -H -lntu 2>/dev/null | awk '{print $5}' | grep -Eq "(^|:)$1$"; }
ask_new_port(){
    local label="$1" old="$2" p
    while :; do
        read -r -p "New $label [$old]: " p
        [[ -z "$p" ]] && p="$old"
        if ! valid_port "$p"; then echo -e "${RED}Invalid port.${NC}"; continue; fi
        if [[ "$p" != "$old" ]] && port_busy "$p"; then echo -e "${RED}Port $p is already in use.${NC}"; continue; fi
        REPLY_PORT="$p"; return 0
    done
}
restart_nginx(){ nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1; }

nginx_role_port(){
    local role="$1" fallback="$2" p
    p=$(grep -RhoE "listen[[:space:]]+[0-9]+[^;]*# MAHBOUB_${role}" /etc/nginx/conf.d /etc/nginx/sites-enabled /etc/nginx/nginx.conf 2>/dev/null | head -1 | grep -oE 'listen[[:space:]]+[0-9]+' | awk '{print $2}')
    [[ -n "$p" ]] && echo "$p" || echo "$fallback"
}
change_nginx(){
    local proto="$1" role="$2" fallback="$3" old new files
    old=$(nginx_role_port "$role" "$fallback")
    echo -e "${CYAN}NGINX $proto current port: $old${NC}"
    ask_new_port "NGINX $proto port" "$old"; new="$REPLY_PORT"
    files=$(grep -RIlE "listen[[:space:]]+$old([[:space:];]|$)" /etc/nginx/conf.d /etc/nginx/sites-enabled /etc/nginx/nginx.conf 2>/dev/null || true)
    if [[ -z "$files" ]]; then echo -e "${RED}No nginx listener for port $old was found.${NC}"; return; fi
    local backups=() f bak
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        bak="${f}.mahboub-port-bak"; cp -a "$f" "$bak"; backups+=("$bak")
        sed -i -E "s/(listen[[:space:]]+)${old}([[:space:];]|$)/\1${new}\2/g" "$f"
        # Mark the selected public listener so it can be found again after a custom port change.
        sed -i -E "s/(listen[[:space:]]+${new}[^;]*)([[:space:]]*;)/\1 # MAHBOUB_${role}\2/" "$f"
    done <<< "$files"
    if restart_nginx; then
        for bak in "${backups[@]}"; do rm -f "$bak"; done
        echo -e "${GREEN}NGINX $proto changed: $old -> $new${NC}"
    else
        for bak in "${backups[@]}"; do [[ -f "$bak" ]] && cp -a "$bak" "${bak%.mahboub-port-bak}" && rm -f "$bak"; done
        echo -e "${RED}NGINX config test failed; previous configuration was restored.${NC}"
    fi
}

stunnel_config(){
    [[ -f /etc/stunnel5/stunnel5.conf ]] && echo /etc/stunnel5/stunnel5.conf || echo /etc/stunnel/stunnel.conf
}
stunnel_current(){
    local cfg="$1" section="$2"
    awk -v s="[$section]" '$0==s{f=1;next} /^\[/{f=0} f && $1=="accept" && $2=="=" {print $3; exit}' "$cfg" 2>/dev/null
}
change_stunnel(){
    local cfg; cfg=$(stunnel_config)
    [[ -f "$cfg" ]] || { echo -e "${RED}Stunnel config not found.${NC}"; pause; return; }
    while :; do
        clear
        echo -e "${PURPLE}========== STUNNEL PORTS ==========${NC}"
        local d o v; d=$(stunnel_current "$cfg" dropbear); o=$(stunnel_current "$cfg" openssh); v=$(stunnel_current "$cfg" openvpn)
        echo "1) DROPBEAR  : ${d:-N/A}"
        echo "2) OPENSSH   : ${o:-N/A}"
        echo "3) OPENVPN   : ${v:-N/A}"
        echo "4) BACK"
        read -r -p "Select: " s
        case "$s" in
            1) change_stunnel_section "$cfg" dropbear "$d";;
            2) change_stunnel_section "$cfg" openssh "$o";;
            3) change_stunnel_section "$cfg" openvpn "$v";;
            4) return;;
            *) echo -e "${RED}Invalid selection.${NC}"; sleep 1;;
        esac
    done
}
change_stunnel_section(){
    local cfg="$1" section="$2" old="$3" new
    [[ -n "$old" ]] || { echo -e "${RED}Section [$section] not found.${NC}"; pause; return; }
    ask_new_port "Stunnel [$section]" "$old"; new="$REPLY_PORT"
    sed -i -E "/^\[$section\]$/,/^\[/{s/^accept[[:space:]]*=[[:space:]]*.*/accept = ${new}/}" "$cfg"
    systemctl restart stunnel5 >/dev/null 2>&1 || systemctl restart stunnel >/dev/null 2>&1 || true
    echo -e "${GREEN}Stunnel [$section] changed: $old -> $new${NC}"; pause
}

change_squid(){
    local cfg=/etc/squid/squid.conf
    [[ -f "$cfg" ]] || { echo -e "${RED}Squid config not found.${NC}"; pause; return; }
    while :; do
        clear; echo -e "${PURPLE}============= SQUID PORTS =============${NC}"
        mapfile -t lines < <(grep -nE '^[[:space:]]*http_port[[:space:]]+[0-9]+' "$cfg")
        local i=1 line num old
        for line in "${lines[@]}"; do num="${line%%:*}"; old=$(sed -n "${num}p" "$cfg" | awk '{print $2}'); echo "$i) $old"; ((i++)); done
        echo "$i) BACK"; read -r -p "Select: " s
        [[ "$s" == "$i" ]] && return
        [[ "$s" =~ ^[0-9]+$ ]] && ((s>=1 && s<i)) || { echo -e "${RED}Invalid selection.${NC}"; sleep 1; continue; }
        num="${lines[$((s-1))]%%:*}"; old=$(sed -n "${num}p" "$cfg" | awk '{print $2}')
        ask_new_port "Squid port" "$old"; local new="$REPLY_PORT"
        sed -i "${num}s/^\([[:space:]]*http_port[[:space:]]*\)[0-9]\+/\1${new}/" "$cfg"
        systemctl restart squid >/dev/null 2>&1 || systemctl restart squid3 >/dev/null 2>&1 || true
        echo -e "${GREEN}Squid changed: $old -> $new${NC}"; pause
    done
}

ohp_service_change(){
    local svc="$1" label="$2" file="/etc/systemd/system/$1" old local new newlocal
    [[ -f "$file" ]] || { echo -e "${RED}$label service not found: $file${NC}"; pause; return; }
    old=$(grep -oE -- '-port[[:space:]]+[0-9]+' "$file" | head -1 | awk '{print $2}')
    local=$(grep -oE -- '-tunnel[[:space:]]+127\.0\.0\.1:[0-9]+' "$file" | head -1 | cut -d: -f2)
    ask_new_port "$label listen port" "$old"; new="$REPLY_PORT"
    read -r -p "Local target port [$local] (22=SSH, 1194=OVPN): " newlocal
    [[ -z "$newlocal" ]] && newlocal="$local"
    valid_port "$newlocal" || { echo -e "${RED}Invalid local port.${NC}"; pause; return; }
    sed -i -E "s#(-port[[:space:]]+)[0-9]+#\1${new}#; s#(-tunnel[[:space:]]+127\.0\.0\.1:)[0-9]+#\1${newlocal}#" "$file"
    systemctl daemon-reload
    systemctl restart "$svc" >/dev/null 2>&1 || true
    echo -e "${GREEN}$label: listen $old -> $new, local $local -> $newlocal${NC}"; pause
}
change_ohp(){
    while :; do
        clear; echo -e "${PURPLE}============== OHP PORTS ==============${NC}"
        echo "1) SSH OHP       : $(grep -oE -- '-port [0-9]+' /etc/systemd/system/ssh-ohp.service 2>/dev/null | awk '{print $2}') -> $(grep -oE -- '-tunnel 127.0.0.1:[0-9]+' /etc/systemd/system/ssh-ohp.service 2>/dev/null | cut -d: -f2)"
        echo "2) DROPBEAR OHP  : $(grep -oE -- '-port [0-9]+' /etc/systemd/system/dropbear-ohp.service 2>/dev/null | awk '{print $2}') -> $(grep -oE -- '-tunnel 127.0.0.1:[0-9]+' /etc/systemd/system/dropbear-ohp.service 2>/dev/null | cut -d: -f2)"
        echo "3) OPENVPN OHP   : $(grep -oE -- '-port [0-9]+' /etc/systemd/system/openvpn-ohp.service 2>/dev/null | awk '{print $2}') -> $(grep -oE -- '-tunnel 127.0.0.1:[0-9]+' /etc/systemd/system/openvpn-ohp.service 2>/dev/null | cut -d: -f2)"
        echo "4) BACK"; read -r -p "Select: " s
        case "$s" in
            1) ohp_service_change ssh-ohp.service 'SSH OHP';;
            2) ohp_service_change dropbear-ohp.service 'DROPBEAR OHP';;
            3) ohp_service_change openvpn-ohp.service 'OPENVPN OHP';;
            4) return;;
            *) echo -e "${RED}Invalid selection.${NC}"; sleep 1;;
        esac
    done
}

change_python_proxy(){
    while :; do
        clear; echo -e "${PURPLE}========== HTTP PYTHON PROXY PORTS ==========${NC}"
        local a b; a=$(grep -oE -- '--port[= ]+[0-9]+' /etc/systemd/system/http-tunnel.service 2>/dev/null | head -1 | grep -oE '[0-9]+$'); b=$(grep -oE -- '--port[= ]+[0-9]+' /etc/systemd/system/mahboub-proxy.service 2>/dev/null | head -1 | grep -oE '[0-9]+$')
        echo "1) OVPN / SSH PY TUNNEL : ${a:-N/A}"
        echo "2) DIRECT HTTP PROXY    : ${b:-N/A}"
        echo "3) CHANGE BOTH"
        echo "4) BACK"; read -r -p "Select: " s
        case "$s" in
            1) python_proxy_one http-tunnel.service 'OVPN / SSH PY TUNNEL' "$a";;
            2) python_proxy_one mahboub-proxy.service 'DIRECT HTTP PROXY' "$b";;
            3) python_proxy_one http-tunnel.service 'OVPN / SSH PY TUNNEL' "$a"; python_proxy_one mahboub-proxy.service 'DIRECT HTTP PROXY' "$b";;
            4) return;;
            *) echo -e "${RED}Invalid selection.${NC}"; sleep 1;;
        esac
    done
}
python_proxy_one(){
    local svc="$1" label="$2" old="$3" new file="/etc/systemd/system/$1"; [[ -f "$file" ]] || { echo -e "${RED}$label service not found.${NC}"; pause; return; }
    [[ -n "$old" ]] || old=$(grep -oE -- '--port[= ]+[0-9]+' "$file" | head -1 | grep -oE '[0-9]+$')
    ask_new_port "$label" "$old"; new="$REPLY_PORT"
    sed -i -E "s#(--port[= ]+)[0-9]+#\1${new}#" "$file"
    systemctl daemon-reload
    systemctl restart "$svc" >/dev/null 2>&1 || true
    echo -e "${GREEN}$label changed: $old -> $new${NC}"; pause
}

change_pptp(){
    local cfg=/etc/default/pptpd old
    [[ -f "$cfg" ]] || { echo -e "${RED}/etc/default/pptpd not found.${NC}"; pause; return; }
    old=$(grep -oE -- '--port[= ]+[0-9]+' "$cfg" | head -1 | grep -oE '[0-9]+$')
    [[ -z "$old" ]] && old=$(ss -H -lntp 2>/dev/null | awk '/pptpd/{split($4,a,":");print a[length(a)]}' | head -1)
    [[ -z "$old" ]] && old=1723
    ask_new_port 'PPTP' "$old"; local new="$REPLY_PORT"
    if grep -qE '^PPTPD_OPTS=' "$cfg"; then sed -i -E "s#^PPTPD_OPTS=.*#PPTPD_OPTS=\"--port ${new}\"#" "$cfg"; else printf '\nPPTPD_OPTS="--port %s"\n' "$new" >> "$cfg"; fi
    iptables -D INPUT -p tcp --dport "$old" -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p tcp --dport "$new" -j ACCEPT 2>/dev/null || true
    iptables-save > /etc/iptables.up.rules 2>/dev/null || true
    systemctl restart pptpd >/dev/null 2>&1 || true
    echo -e "${GREEN}PPTP changed: $old -> $new${NC}"; pause
}

change_l2tp(){
    local old new
    old=$(grep -oE 'leftprotoport=17/[0-9]+' /etc/ipsec.conf 2>/dev/null | head -1 | cut -d/ -f2)
    [[ -z "$old" ]] && old=$(grep -oE '^port[[:space:]]*=[[:space:]]*[0-9]+' /etc/xl2tpd/xl2tpd.conf 2>/dev/null | awk '{print $3}')
    [[ -z "$old" ]] && old=1701
    ask_new_port 'L2TP/IPsec UDP' "$old"; new="$REPLY_PORT"
    [[ -f /etc/ipsec.conf ]] && sed -i -E "s#leftprotoport=17/${old}#leftprotoport=17/${new}#; s#rightprotoport=17/%any#rightprotoport=17/%any#" /etc/ipsec.conf
    [[ -f /etc/xl2tpd/xl2tpd.conf ]] && sed -i -E "s#^(port[[:space:]]*=[[:space:]]*)${old}#\1${new}#" /etc/xl2tpd/xl2tpd.conf
    iptables -D INPUT -p udp --dport "$old" -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p udp --dport "$new" -j ACCEPT 2>/dev/null || true
    iptables-save > /etc/iptables.up.rules 2>/dev/null || true
    systemctl restart xl2tpd >/dev/null 2>&1 || true
    systemctl restart ipsec >/dev/null 2>&1 || true
    echo -e "${GREEN}L2TP/IPsec changed: $old -> $new${NC}"; pause
}

change_ss_base(){
    local cfg=/usr/bin/addss old_tls old_http new_tls new_http
    [[ -f "$cfg" ]] || cfg="/root/addss"
    [[ -f "$cfg" ]] || { echo -e "${RED}Shadowsocks addss script not found.${NC}"; pause; return; }
    old_tls=$(grep -E '^tls=' "$cfg" | head -1 | sed -E 's/.*="?([0-9]+)"?/\1/')
    old_http=$(grep -E '^http=' "$cfg" | head -1 | sed -E 's/.*="?([0-9]+)"?/\1/')
    [[ -z "$old_tls" ]] && old_tls=2443; [[ -z "$old_http" ]] && old_http=3443
    ask_new_port 'Shadowsocks TLS base port' "$old_tls"; new_tls="$REPLY_PORT"
    ask_new_port 'Shadowsocks HTTP base port' "$old_http"; new_http="$REPLY_PORT"
    sed -i -E "s/^tls=[0-9]+$/tls=${new_tls}/; s/^http=[0-9]+$/http=${new_http}/" "$cfg"
    echo -e "${GREEN}Future Shadowsocks TLS/HTTP base ports changed to $new_tls / $new_http.${NC} Existing accounts keep their current ports.${NC}"; pause
}

change_ssr_base(){
    local cfg=/usr/bin/addssr old=1443 new
    [[ -f "$cfg" ]] || cfg="/root/addssr"
    [[ -f "$cfg" ]] || { echo -e "${RED}SSR addssr script not found.${NC}"; pause; return; }
    ask_new_port 'SSR starting port' "$old"; new="$REPLY_PORT"
    sed -i -E "s/^ssr_port=[0-9]+$/ssr_port=${new}/" "$cfg"
    echo -e "${GREEN}Future SSR starting port changed to $new. Existing SSR accounts keep their current ports.${NC}"; pause
}

change_openvpn(){ command -v portovpn >/dev/null 2>&1 && portovpn || { echo -e "${RED}OpenVPN port changer is not installed.${NC}"; pause; }; }
change_sstp(){ command -v portsstp >/dev/null 2>&1 && portsstp || { echo -e "${RED}SSTP port changer is not installed.${NC}"; pause; }; }
change_wireguard(){ command -v portwg >/dev/null 2>&1 && portwg || { echo -e "${RED}WireGuard port changer is not installed.${NC}"; pause; }; }

current_nginx(){
    local p="$1"
    if ss -H -lntp 2>/dev/null | awk -v p=":$p" '$4 ~ p {print; exit}' | grep -q nginx; then echo "$p"; else
        grep -RhoE "listen[[:space:]]+$p([[:space:];]|$)" /etc/nginx/conf.d /etc/nginx/sites-enabled /etc/nginx/nginx.conf 2>/dev/null | head -1 | grep -oE "$p" || echo "N/A"
    fi
}
current_squid(){ grep -E '^[[:space:]]*http_port[[:space:]]+[0-9]+' /etc/squid/squid.conf 2>/dev/null | awk '{print $2}' | paste -sd/ - || echo "N/A"; }
current_stunnel(){ local c=$(stunnel_config); [[ -f "$c" ]] && printf '%s/%s/%s' "$(stunnel_current "$c" dropbear)" "$(stunnel_current "$c" openssh)" "$(stunnel_current "$c" openvpn)" || echo "N/A"; }
current_ohp(){ printf '%s/%s/%s' "$(grep -oE -- '-port [0-9]+' /etc/systemd/system/ssh-ohp.service 2>/dev/null | awk '{print $2}')" "$(grep -oE -- '-port [0-9]+' /etc/systemd/system/dropbear-ohp.service 2>/dev/null | awk '{print $2}')" "$(grep -oE -- '-port [0-9]+' /etc/systemd/system/openvpn-ohp.service 2>/dev/null | awk '{print $2}')"; }
current_pyproxy(){ printf '%s/%s' "$(grep -oE -- '--port[= ]+[0-9]+' /etc/systemd/system/http-tunnel.service 2>/dev/null | head -1 | grep -oE '[0-9]+$')" "$(grep -oE -- '--port[= ]+[0-9]+' /etc/systemd/system/mahboub-proxy.service 2>/dev/null | head -1 | grep -oE '[0-9]+$')"; }
current_ovpn(){
    local a b; a=$(ss -H -lntp 2>/dev/null | awk '/openvpn/{print $4}' | sed 's/.*://' | paste -sd/ -); b=$(ss -H -lnup 2>/dev/null | awk '/openvpn/{print $4}' | sed 's/.*://' | paste -sd/ -); printf '%s/%s' "${a:-N/A}" "${b:-N/A}";
}
current_sstp(){ grep -i '^port=' /etc/accel-ppp.conf 2>/dev/null | head -1 | cut -d= -f2 || echo N/A; }
current_pptp(){ local p; p=$(grep -oE -- '--port[= ]+[0-9]+' /etc/default/pptpd 2>/dev/null | head -1 | grep -oE '[0-9]+$'); [[ -n "$p" ]] && echo "$p" || echo "1723"; }
current_l2tp(){ local p; p=$(grep -oE 'leftprotoport=17/[0-9]+' /etc/ipsec.conf 2>/dev/null | head -1 | cut -d/ -f2); [[ -n "$p" ]] && echo "$p" || echo "1701"; }
current_wg(){ grep -E '^SERVER_PORT=' /etc/wireguard/params 2>/dev/null | cut -d= -f2 || echo 7070; }
current_ss(){ local c=/usr/bin/addss; [[ -f "$c" ]] || c=/root/addss; printf '%s/%s' "$(grep -E '^tls=' "$c" 2>/dev/null | head -1 | sed -E 's/.*="?([0-9]+)"?/\1/')" "$(grep -E '^http=' "$c" 2>/dev/null | head -1 | sed -E 's/.*="?([0-9]+)"?/\1/')"; }
current_ssr(){ local c=/usr/bin/addssr; [[ -f "$c" ]] || c=/root/addssr; grep -E '^ssr_port=' "$c" 2>/dev/null | head -1 | sed -E 's/.*=([0-9]+)/\1/' || echo 1443; }

show_menu(){
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              PORT SETTINGS                   ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
    echo -e "${WHITE}║ 01) NGINX HTTP          : $(nginx_role_port NGINX_HTTP 80)            ${NC}"
    echo -e "${WHITE}║ 02) NGINX HTTPS         : $(nginx_role_port NGINX_HTTPS 443)           ${NC}"
    echo -e "${WHITE}║ 03) STUNNEL             : $(current_stunnel)       ${NC}"
    echo -e "${WHITE}║ 04) SQUID               : $(current_squid)         ${NC}"
    echo -e "${WHITE}║ 05) OHP                 : $(current_ohp)      ${NC}"
    echo -e "${WHITE}║ 06) HTTP PROXY          : $(current_pyproxy)         ${NC}"
    echo -e "${WHITE}║ 07) OVPN                : TCP/UDP $(current_ovpn)     ${NC}"
    echo -e "${WHITE}║ 08) SSTP                : $(current_sstp)              ${NC}"
    echo -e "${WHITE}║ 09) PPTP                : $(current_pptp)             ${NC}"
    echo -e "${WHITE}║ 10) L2TP                : $(current_l2tp)              ${NC}"
    echo -e "${WHITE}║ 11) WIREGUARD           : $(current_wg)              ${NC}"
    echo -e "${WHITE}║ 12) SHADOWSOCKS         : $(current_ss)         ${NC}"
    echo -e "${WHITE}║ 13) SHADOWSOCKS-R / SSR : $(current_ssr)              ${NC}"
    echo -e "${WHITE}║ 14) BACK                                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}SSH port is not changed here.${NC}"
}

while :; do
    show_menu
    read -r -p "Select option [1-14]: " port
    case "$port" in
        1) change_nginx HTTP NGINX_HTTP 80;;
        2) change_nginx HTTPS NGINX_HTTPS 443;;
        3) change_stunnel;;
        4) change_squid;;
        5) change_ohp;;
        6) change_python_proxy;;
        7) change_openvpn;;
        8) change_sstp;;
        9) change_pptp;;
        10) change_l2tp;;
        11) change_wireguard;;
        12) change_ss_base;;
        13) change_ssr_base;;
        14) clear; exit 0;;
        *) echo -e "${RED}Invalid selection.${NC}"; sleep 1;;
    esac
done
