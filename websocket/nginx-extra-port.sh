#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Nginx Extra Port Manager
# Adds isolated Nginx listener files without modifying ports 80/443.
set -euo pipefail

BASE=/etc/nginx/conf.d
STATE=/etc/nginx/mahboub-extra-ports
mkdir -p "$BASE" "$STATE"

c='[0;1;36m'; g='[0;1;32m'; y='[0;1;33m'; r='[0;1;31m'; w='[0m'

valid_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && (( 1 <= 10#$1 && 10#$1 <= 65535 )) && (( 10#$1 != 80 && 10#$1 != 443 ))
}

port_in_use() {
    ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq ":$1$|\\]\\:$1$"
}

render_locations() {
    local mode="$1"
    local suffix=none
    [[ "$mode" == tls ]] && suffix=tls
    local vmess_ws vmess_x vmess_h vmess_g vless_ws vless_x vless_h vless_g trojan_ws trojan_x trojan_h trojan_g sshws
    if [[ "$suffix" == tls ]]; then
        vmess_ws=11001; vmess_x=11003; vmess_h=11005; vmess_g=11007
        vless_ws=11011; vless_x=11013; vless_h=11015; vless_g=11017
        trojan_ws=11021; trojan_x=11023; trojan_h=11025; trojan_g=11027
        sshws=10089
    else
        vmess_ws=11002; vmess_x=11004; vmess_h=11006; vmess_g=11008
        vless_ws=11012; vless_x=11014; vless_h=11016; vless_g=11018
        trojan_ws=11022; trojan_x=11024; trojan_h=11026; trojan_g=11028
        sshws=10088
    fi
    cat <<NGINX
    location /vmess/ { proxy_pass http://127.0.0.1:$vmess_ws; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /vmess-xhttp/ { proxy_pass http://127.0.0.1:$vmess_x; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /vmess-httpupgrade/ { proxy_pass http://127.0.0.1:$vmess_h; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /vmess-grpc { grpc_pass grpc://127.0.0.1:$vmess_g; grpc_set_header Host \$host; }
    location /vless/ { proxy_pass http://127.0.0.1:$vless_ws; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /vless-xhttp/ { proxy_pass http://127.0.0.1:$vless_x; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /vless-httpupgrade/ { proxy_pass http://127.0.0.1:$vless_h; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /vless-grpc { grpc_pass grpc://127.0.0.1:$vless_g; grpc_set_header Host \$host; }
    location /trojan/ { proxy_pass http://127.0.0.1:$trojan_ws; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /trojan-xhttp/ { proxy_pass http://127.0.0.1:$trojan_x; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /trojan-httpupgrade/ { proxy_pass http://127.0.0.1:$trojan_h; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /trojan-grpc { grpc_pass grpc://127.0.0.1:$trojan_g; grpc_set_header Host \$host; }
    location /trojango { proxy_pass http://127.0.0.1:10087; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; }
    location /ssh-ws { proxy_pass http://127.0.0.1:$sshws; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; proxy_set_header X-Real-Host 127.0.0.1:22; proxy_set_header X-Pass ""; }
    location /sshws/ { proxy_pass http://127.0.0.1:$sshws; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; proxy_set_header X-Real-Host 127.0.0.1:22; proxy_set_header X-Pass ""; }
    location / { root /home/vps/public_html; index index.html; }
NGINX
}

add_port() {
    local port="$1" mode="$2" file="$BASE/mahboub-extra-${port}.conf"
    if ! valid_port "$port"; then echo -e "${r}Invalid port. Use 1-65535 except 80 and 443.${w}"; return 1; fi
    if [[ -e "$file" ]]; then echo -e "${y}Port $port is already managed here.${w}"; return 1; fi
    if port_in_use "$port"; then echo -e "${r}Port $port is already in use by another listener.${w}"; return 1; fi
    if [[ "$mode" == tls && ! -s /etc/xray/xray.crt ]]; then echo -e "${r}TLS certificate /etc/xray/xray.crt is missing.${w}"; return 1; fi
    {
        if [[ "$mode" == tls ]]; then
            echo "server { listen $port ssl; server_name _; ssl_certificate /etc/xray/xray.crt; ssl_certificate_key /etc/xray/xray.key; ssl_protocols TLSv1.2 TLSv1.3; proxy_read_timeout 3600s; proxy_send_timeout 3600s;"
            render_locations tls
        else
            echo "server { listen $port; server_name _; proxy_read_timeout 3600s; proxy_send_timeout 3600s;"
            render_locations none
        fi
        echo '}'
    } > "$file"
    if nginx -t; then
        systemctl reload nginx
        printf '%s\n' "$mode" > "$STATE/$port"
        echo -e "${g}Nginx $mode port $port added successfully.${w}"
    else
        rm -f "$file"
        echo -e "${r}Nginx test failed; port $port was not added.${w}"
        return 1
    fi
}

remove_port() {
    local port="$1" file="$BASE/mahboub-extra-${port}.conf"
    if ! valid_port "$port"; then echo -e "${r}Invalid port.${w}"; return 1; fi
    if [[ ! -e "$file" ]]; then echo -e "${y}Managed port $port not found.${w}"; return 1; fi
    rm -f "$file" "$STATE/$port"
    nginx -t && systemctl reload nginx
    echo -e "${g}Nginx extra port $port removed. Ports 80/443 were not changed.${w}"
}

list_ports() {
    echo -e "${c}MAHBOUB TUNNEL PREMIUM - EXTRA NGINX PORTS${w}"
    if compgen -G "$STATE/*" >/dev/null; then
        for f in "$STATE"/*; do printf '  %-6s %s\n' "$(basename "$f")" "$(cat "$f")"; done
    else
        echo '  No extra Nginx ports configured.'
    fi
}

while true; do
    clear
    echo -e "${c}╭────────────────────────────────────────────────────╮${w}"
    echo -e "${c}│       ★ MAHBOUB TUNNEL PREMIUM ★                  │${w}"
    echo -e "${c}│            NGINX EXTRA PORT MANAGER               │${w}"
    echo -e "${c}╰────────────────────────────────────────────────────╯${w}"
    echo -e "${g}[01]${w} Add HTTP port"
    echo -e "${g}[02]${w} Add HTTPS/TLS port"
    echo -e "${g}[03]${w} Remove extra port"
    echo -e "${g}[04]${w} List extra ports"
    echo -e "${g}[05]${w} Back"
    echo
    read -rp 'Select option: ' op
    case "$op" in
        1|01) read -rp 'Enter HTTP port (not 80/443): ' p; add_port "$p" none; read -rp 'Press Enter...' _ ;;
        2|02) read -rp 'Enter HTTPS/TLS port (not 80/443): ' p; add_port "$p" tls; read -rp 'Press Enter...' _ ;;
        3|03) read -rp 'Enter managed port to remove: ' p; remove_port "$p"; read -rp 'Press Enter...' _ ;;
        4|04) list_ports; read -rp 'Press Enter...' _ ;;
        5|05) break ;;
        *) echo -e "${y}Invalid option.${w}"; sleep 1 ;;
    esac
done
