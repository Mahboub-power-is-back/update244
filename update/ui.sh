#!/bin/bash
# ============================================================
# MAHBOUB TUNNEL PREMIUM - Shared UI
# Modern Ubuntu/Debian compatible terminal interface.
# ============================================================

RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
BLACK=$'\033[30m'
RED=$'\033[38;5;203m'
GREEN=$'\033[38;5;46m'
YELLOW=$'\033[38;5;226m'
BLUE=$'\033[38;5;39m'
PURPLE=$'\033[38;5;141m'
CYAN=$'\033[38;5;51m'
WHITE=$'\033[38;5;255m'
GRAY=$'\033[38;5;245m'

UI_W=76

ui_repeat() {
    local char="${1:-─}" n="${2:-0}" i
    (( n < 0 )) && n=0
    for ((i=0; i<n; i++)); do printf '%s' "$char"; done
}

ui_plain_len() {
    # Strip ANSI CSI sequences before measuring text width.
    printf '%b' "$1" | sed $'s/\033\[[0-9;]*m//g' | wc -m
}

ui_center() {
    local text="$1" len pad
    len="$(ui_plain_len "$text")"
    pad=$(( (UI_W-len)/2 ))
    (( pad < 0 )) && pad=0
    printf '%*s%b\n' "$pad" '' "$text"
}

ui_header() {
    clear 2>/dev/null || true
    printf '\n'
    printf '%b╔════════════════════════════════════════════════════════════════════════════╗%b\n' "$PURPLE" "$RESET"
    printf '%b║%b        %b★ MAHBOUB %bTUNNEL %bPREMIUM ★%b                                  %b║%b\n' \
        "$PURPLE" "$RESET" "$CYAN" "$WHITE" "$PURPLE" "$RESET" "$PURPLE" "$RESET"
    printf '%b║%b          %bFast%b • %bSecure%b • %bStable%b • %bUnlimited%b                         %b║%b\n' \
        "$PURPLE" "$RESET" "$GREEN" "$RESET" "$CYAN" "$RESET" "$YELLOW" "$RESET" "$PURPLE" "$RESET" "$PURPLE" "$RESET"
    printf '%b╚════════════════════════════════════════════════════════════════════════════╝%b\n' "$PURPLE" "$RESET"
}

ui_title() {
    local title="$*"
    local inner=$((UI_W-6-${#title}))
    (( inner < 2 )) && inner=2
    local left=$((inner/2)) right=$((inner-left))
    printf '%b╭%s%b[ %b%s%b ]%s╮%b\n' \
        "$PURPLE" "$(ui_repeat '─' "$left")" "$PURPLE" "$CYAN" "$title" "$PURPLE" "$(ui_repeat '─' "$right")" "$RESET"
}

ui_bottom() {
    printf '%b╰%s╯%b\n' "$PURPLE" "$(ui_repeat '─' $((UI_W-2)))" "$RESET"
}

ui_online_clients() {
    command -v ss >/dev/null 2>&1 || { printf '0'; return; }

    # Count unique remote IPs with ESTABLISHED TCP sessions whose local port
    # belongs to a public/listening service. This is a live kernel connection
    # count; no fake/demo value is used.
    ss -H -lnt 2>/dev/null | awk '
    {
        local=$4
        n=split(local,a,":")
        port=a[n]
        addr=local
        sub(/:[^:]+$/, "", addr)
        if (addr ~ /^0\.0\.0\.0$/ || addr ~ /^\*$/ || addr ~ /^\[::\]$/ || addr ~ /^::$/) {
            if (port ~ /^[0-9]+$/) listen[port]=1
        }
    }
    END { for (p in listen) printf "%s,", p }' > /tmp/.mahboub_ports.$$ 2>/dev/null || true

    local ports
    ports="$(cat /tmp/.mahboub_ports.$$ 2>/dev/null | sed 's/,$//')"
    rm -f /tmp/.mahboub_ports.$$ 2>/dev/null || true

    # SSH can be configured with ListenAddress and therefore not appear as a
    # wildcard listener in every configuration.
    if [ -r /etc/ssh/sshd_config ]; then
        local ssh_ports
        ssh_ports="$(awk 'tolower($1)=="port" && $2 ~ /^[0-9]+$/ {print $2}' /etc/ssh/sshd_config 2>/dev/null | paste -sd, -)"
        [ -n "$ssh_ports" ] && ports="${ports:+$ports,}$ssh_ports"
    fi

    # Keep the known proxy port visible to the counter if it is intentionally
    # bound publicly. The bundled MAHBOUB proxy defaults to 127.0.0.1:8484.
    [ -z "$ports" ] && { printf '0'; return; }

    ss -H -tn state established 2>/dev/null | awk -v ports="$ports" '
    BEGIN {
        split(ports,p,",");
        for (i in p) allowed[p[i]]=1
    }
    {
        local=$4; remote=$5
        n=split(local,a,":"); lp=a[n]
        rip=remote; sub(/:[^:]+$/, "", rip)
        gsub(/^\[/,"",rip); gsub(/\]$/,"",rip)
        if (allowed[lp] && rip !~ /^(127\.0\.0\.1|::1|0\.0\.0\.0)$/) clients[rip]=1
    }
    END { c=0; for (ip in clients) c++; print c+0 }'
}

ui_info() {
    local os domain now up users ip
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        os="${PRETTY_NAME:-${NAME:-Linux}}"
    else
        os="$(uname -s 2>/dev/null || printf Linux)"
    fi
    domain="$(cat /etc/xray/domain 2>/dev/null || hostname -f 2>/dev/null || hostname 2>/dev/null || printf unknown)"
    now="$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || printf unknown)"
    up="$(uptime -p 2>/dev/null | sed 's/^up //' || true)"
    [ -n "$up" ] || up=unknown
    users="$(ui_online_clients)"
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -n "$ip" ] || ip=unknown

    ui_title 'SYSTEM INFORMATION'
    printf '%b│  🐧  %-15s : %b%s%b\n' "$GRAY" 'OS' "$YELLOW" "$os" "$RESET"
    printf '%b│  🌐  %-15s : %b%s%b\n' "$GRAY" 'Domain' "$CYAN" "$domain" "$RESET"
    printf '%b│  ◷   %-15s : %b%s%b\n' "$GRAY" 'Time' "$YELLOW" "$now" "$RESET"
    printf '%b│  ◷   %-15s : %b%s%b\n' "$GRAY" 'Uptime' "$GREEN" "$up" "$RESET"
    printf '%b│  👥  %-15s : %b%s Connected%b\n' "$GRAY" 'Online Users' "$GREEN" "$users" "$RESET"
    printf '%b│  IP  %-15s : %b%s%b\n' "$GRAY" 'Address' "$BLUE" "$ip" "$RESET"
    ui_bottom
    printf '\n'
}

ui_item() {
    local n="$1" label="$2" icon="${3:-➤}" c="${4:-$GREEN}"
    printf '%b│%b  %b[%02d]%b  %-42s %b%s%b %b›%b\n' \
        "$GRAY" "$RESET" "$c" "$n" "$RESET" "$label" "$c" "$icon" "$RESET" "$GRAY" "$RESET"
}

ui_main_item() {
    local n="$1" label="$2" icon="${3:-➤}" c="${4:-$GREEN}"
    printf '%b│   %b[%02d]%b  %-31s %b%s%b  %b›%b' \
        "$GRAY" "$c" "$n" "$RESET" "$label" "$c" "$icon" "$RESET" "$GRAY" "$RESET"
}

ui_prompt() {
    local max="${1:-13}"
    printf '\n%b╭─[ %bSELECT OPTION%b ]%b%s╮\n' \
        "$PURPLE" "$CYAN" "$PURPLE" "$RESET" "$(ui_repeat '─' $((UI_W-19)))"
    printf '%b│%b  Choose an option [ %b1-%s%b ] : ' "$GRAY" "$RESET" "$GREEN" "$max" "$RESET"
}

ui_pause() {
    printf '\n%bPress Enter to continue...%b' "$GRAY" "$RESET"
    read -r
}

ui_require() {
    local fn="$1"
    if ! command -v "$fn" >/dev/null 2>&1; then
        printf '%bCommand not found: %s%b\n' "$RED" "$fn" "$RESET"
        ui_pause
        return 1
    fi
}

ui_submenu() {
    ui_header
    ui_title "$1"
}
