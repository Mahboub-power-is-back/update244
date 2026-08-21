#!/bin/bash
# MAHBOUB PROXY - HTTP TUNNEL / PROXY manager
# Both modes use port 80. Only one mode can be active at a time.
PY_TUNNEL_SERVICE="http-tunnel.service"
DIRECT_PROXY_SERVICE="mahboub-proxy.service"
PY_TUNNEL_BIN="/usr/local/bin/mahboub-http-tunnel.py"
DIRECT_PROXY_BIN="/usr/local/bin/mahboub-proxy.py"

_http_proxy_stop_all() {
    systemctl disable --now "$PY_TUNNEL_SERVICE" >/dev/null 2>&1 || true
    systemctl disable --now "$DIRECT_PROXY_SERVICE" >/dev/null 2>&1 || true
}

_http_proxy_start() {
    local service="$1"
    local binary="$2"
    local label="$3"

    clear
    if [ ! -f "$binary" ]; then
        printf '%b%s is not installed: %s%b\n' "$RED" "$label" "$binary" "$RESET"
        sleep 2
        return
    fi

    _http_proxy_stop_all
    systemctl daemon-reload
    systemctl enable "$service" >/dev/null 2>&1
    systemctl restart "$service"

    if systemctl is-active --quiet "$service"; then
        printf '%b✓ %s ENABLED on port 80%b\n' "$GREEN" "$label" "$RESET"
    else
        printf '%b✗ %s failed to start.%b\n' "$RED" "$label" "$RESET"
        printf '%bCheck: journalctl -u %s -n 50%b\n' "$YELLOW" "$service" "$RESET"
    fi
    sleep 2
}

http_tunnel_menu() {
    while true; do
        ui_header
        ui_title 'HTTP TUNNEL / PROXY'

        local active='NONE'
        if systemctl is-active --quiet "$PY_TUNNEL_SERVICE"; then
            active='OVPN / SSH PY TUNNEL'
        elif systemctl is-active --quiet "$DIRECT_PROXY_SERVICE"; then
            active='DIRECT HTTP PROXY'
        fi

        printf '%b│%b  %bACTIVE%b : %-48s%b│%b\n' \
            "$GRAY" "$RESET" "$CYAN" "$RESET" "$active" "$GRAY" "$RESET"
        printf '%b│%b%*s%b[%02d]%b  %-27s %b%s%b  %b›%b%*s%b│%b\n' \
            "$GRAY" "$RESET" 14 '' "$GREEN" 1 "$RESET" 'OVPN / SSH PY TUNNEL' "$GREEN" 'S' "$RESET" "$GRAY" "$RESET" 14 '' "$GRAY" "$RESET"
        printf '%b│%b%*s%b[%02d]%b  %-27s %b%s%b  %b›%b%*s%b│%b\n' \
            "$GRAY" "$RESET" 14 '' "$CYAN" 2 "$RESET" 'DIRECT HTTP PROXY' "$CYAN" '⇄' "$RESET" "$GRAY" "$RESET" 14 '' "$GRAY" "$RESET"
        printf '%b│%b%*s%b[%02d]%b  %-27s %b%s%b  %b›%b%*s%b│%b\n' \
            "$GRAY" "$RESET" 14 '' "$RED" 3 "$RESET" 'DISABLE BOTH' "$RED" '×' "$RESET" "$GRAY" "$RESET" 14 '' "$GRAY" "$RESET"
        printf '%b│%b%*s%b[%02d]%b  %-27s %b%s%b  %b›%b%*s%b│%b\n' \
            "$GRAY" "$RESET" 14 '' "$YELLOW" 4 "$RESET" 'BACK' "$YELLOW" '↩' "$RESET" "$GRAY" "$RESET" 14 '' "$GRAY" "$RESET"
        ui_bottom
        ui_prompt 4
        read -r choice
        case "$choice" in
            1) _http_proxy_start "$PY_TUNNEL_SERVICE" "$PY_TUNNEL_BIN" 'OVPN / SSH PY TUNNEL' ;;
            2) _http_proxy_start "$DIRECT_PROXY_SERVICE" "$DIRECT_PROXY_BIN" 'DIRECT HTTP PROXY' ;;
            3)
                clear
                _http_proxy_stop_all
                printf '%bHTTP TUNNEL / PROXY DISABLED.%b\n' "$YELLOW" "$RESET"
                sleep 2
                ;;
            4) clear; return ;;
            *) printf '%bInvalid selection.%b\n' "$RED" "$RESET"; sleep 1 ;;
        esac
    done
}
