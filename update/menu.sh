#!/bin/bash

# MAHBOUB TUNNEL PREMIUM - Main Menu
# UI-only redesign: service functions and menu command names are unchanged.

# ANSI colors
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[38;5;51m'
GREEN='\033[38;5;46m'
BLUE='\033[38;5;39m'
PURPLE='\033[38;5;141m'
YELLOW='\033[38;5;226m'
RED='\033[38;5;203m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;245m'

TERM_WIDTH=74

repeat_char() {
    local char="$1" count="$2"
    local i=0
    while [ $i -lt $count ]; do printf '%s' "$char"; i=$((i+1)); done
}

center_line() {
    local text="$1" width="${2:-$TERM_WIDTH}"
    local len=${#text}
    local pad=$(( (width - len) / 2 ))
    (( pad < 0 )) && pad=0
    printf '%*s%b\n' "$pad" '' "$text"
}

line() {
    local color="$1" char="$2" width="${3:-$TERM_WIDTH}"
    printf '%b%s%b\n' "$color" "$(repeat_char "$char" "$width")" "$RESET"
}

section() {
    local title="$1"
    printf '%b╭─[ %b%s%b ]%b' "$PURPLE" "$CYAN" "$title" "$PURPLE" "$RESET"
    local used=$((6 + ${#title}))
    local remaining=$((TERM_WIDTH - used))
    (( remaining < 1 )) && remaining=1
    printf '%b%s╮%b\n' "$PURPLE" "$(repeat_char '─' "$remaining")" "$RESET"
}

menu_item() {
    local n="$1" label="$2" color="$3"
    printf '%b│ %b[%02d]%b %-29s %b›%b\n' "$GRAY" "$color" "$n" "$RESET" "$label" "$color" "$RESET"
}

get_system_info() {
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        OS="${PRETTY_NAME:-${NAME:-Linux}}"
    else
        OS="$(uname -s 2>/dev/null || echo Linux)"
    fi

    if [ -r /etc/xray/domain ]; then
        DOMAIN="$(cat /etc/xray/domain 2>/dev/null)"
    else
        DOMAIN="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
    fi

    TIME="$(date '+%Y-%m-%d %H:%M:%S')"
    UPTIME="$(uptime -p 2>/dev/null | sed 's/^up //')"
    [ -z "$UPTIME" ] && UPTIME="unknown"
    IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -z "$IP" ] && IP="unknown"

    # Preserve the original meaning: count unique interactive login users.
    ONLINE_USERS="$(who 2>/dev/null | awk '{print $1}' | sort -u | sed '/^$/d' | wc -l)"
}

show_header() {
    clear 2>/dev/null || true
    echo
    center_line "${BOLD}${CYAN}★ MAHBOUB${WHITE} TUNNEL ${PURPLE}PREMIUM ★${RESET}"
    center_line "${DIM}${WHITE}Fast ${CYAN}•${WHITE} Secure ${PURPLE}•${WHITE} Stable ${GREEN}•${WHITE} Premium${RESET}"
    echo
}

show_system_info() {
    section "SYSTEM INFORMATION"
    printf '%b│%b %-15s : %b%s%b\n' "$GRAY" "$RESET" 'OS' "$YELLOW" "$OS" "$RESET"
    printf '%b│%b %-15s : %b%s%b\n' "$GRAY" "$RESET" 'Domain' "$CYAN" "$DOMAIN" "$RESET"
    printf '%b│%b %-15s : %b%s%b\n' "$GRAY" "$RESET" 'Time' "$YELLOW" "$TIME" "$RESET"
    printf '%b│%b %-15s : %b%s%b\n' "$GRAY" "$RESET" 'Uptime' "$GREEN" "$UPTIME" "$RESET"
    printf '%b│%b %-15s : %b%s%b\n' "$GRAY" "$RESET" 'Online Users' "$GREEN" "${ONLINE_USERS} Connected" "$RESET"
    printf '%b│%b %-15s : %b%s%b\n' "$GRAY" "$RESET" 'IP Address' "$BLUE" "$IP" "$RESET"
    printf '%b╰%s╯%b\n' "$GRAY" "$(repeat_char '─' $((TERM_WIDTH-2)))" "$RESET"
}

show_main_menu() {
    echo
    section "MAIN MENU"
    printf '%b│%b  %b[01]%b SSH & OPENVPN        %b[06]%b SHADOWSOCKS\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$PURPLE" "$RESET"
    printf '%b│%b  %b[02]%b L2TP / IPSEC VPN      %b[07]%b SHADOWSOCKS-R\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$PURPLE" "$RESET"
    printf '%b│%b  %b[03]%b PPTP VPN              %b[08]%b VMESS (XRAY)\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$BLUE" "$RESET"
    printf '%b│%b  %b[04]%b SSTP VPN              %b[09]%b VLESS (XRAY)\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$CYAN" "$RESET"
    printf '%b│%b  %b[05]%b WIREGUARD VPN          %b[10]%b TROJAN (XRAY)\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$RED" "$RESET"
    printf '%b│%b  %b[11]%b TROJAN GO              %b[12]%b SETTINGS\n' "$GRAY" "$RESET" "$RED" "$RESET" "$YELLOW" "$RESET"
    printf '%b│%b  %b[13]%b EXIT\n' "$GRAY" "$RESET" "$RED" "$RESET"
    printf '%b╰%s╯%b\n' "$GRAY" "$(repeat_char '─' $((TERM_WIDTH-2)))" "$RESET"
}

show_prompt() {
    echo
    printf '%b╭─[ %bSELECT OPTION%b ]%b%s╮\n' "$PURPLE" "$CYAN" "$PURPLE" "$RESET" "$(repeat_char '─' $((TERM_WIDTH-19)))"
    printf '%b│%b Choose [ %b1-13%b ] : ' "$GRAY" "$RESET" "$GREEN" "$RESET"
}

get_system_info
show_header
show_system_info
show_main_menu
show_prompt
read -r menu

case "$menu" in
    1) clear; sshovpnmenu ;;
    2) clear; l2tpmenu ;;
    3) clear; pptpmenu ;;
    4) clear; sstpmenu ;;
    5) clear; wgmenu ;;
    6) clear; ssmenu ;;
    7) clear; ssrmenu ;;
    8) clear; vmessmenu ;;
    9) clear; vlessmenu ;;
    10) clear; trmenu ;;
    11) clear; trgomenu ;;
    12) clear; setmenu ;;
    13) clear; exit 0 ;;
    *)
        printf '%b\nInvalid selection. Please choose 1-13.%b\n' "$RED" "$RESET"
        sleep 1
        exec "$0"
        ;;
esac
