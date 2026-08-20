#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu UI
RESET='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[38;5;51m'; GREEN='\033[38;5;46m'; BLUE='\033[38;5;39m'
PURPLE='\033[38;5;141m'; YELLOW='\033[38;5;226m'; RED='\033[38;5;203m'
WHITE='\033[38;5;255m'; GRAY='\033[38;5;245m'
W=68
repeat_char(){ local c="$1" n="$2"; printf '%*s' "$n" '' | tr ' ' "$c"; }
center(){ local t="$1"; local p=$(( (W-${#t})/2 )); ((p<0))&&p=0; printf '%*s%b\n' "$p" '' "$t"; }
header(){
 clear 2>/dev/null || true; echo
 center "${BOLD}${CYAN}★ MAHBOUB${WHITE} TUNNEL ${PURPLE}PREMIUM ★${RESET}"
 center "${DIM}${WHITE}Professional • Fast • Secure • Stable${RESET}"; echo
}
box_title(){ local t="$1"; printf '%b╭─[ %b%s%b ]%b' "$PURPLE" "$CYAN" "$t" "$PURPLE" "$RESET"; printf '%b%s╮%b\n' "$PURPLE" "$(repeat_char '─' $((W-6-${#t})))" "$RESET"; }
item(){ local n="$1" label="$2" c="${3:-$GREEN}"; printf '%b│  %b[%02d]%b %-52s %b›%b\n' "$GRAY" "$c" "$n" "$RESET" "$label" "$c" "$RESET"; }
footer(){ printf '%b╰%s╯%b\n' "$GRAY" "$(repeat_char '─' $((W-2)))" "$RESET"; echo; printf '%b╭─[ %bSELECT OPTION%b ]%b%s╮\n' "$PURPLE" "$CYAN" "$PURPLE" "$RESET" "$(repeat_char '─' $((W-19)))"; printf '%b│%b  Choose an option [ %b1-%s%b ] : ' "$GRAY" "$RESET" "$GREEN" "$1" "$RESET"; }
sysline(){ local k="$1" v="$2" c="$3"; printf '%b│%b %-13s : %b%s%b\n' "$GRAY" "$RESET" "$k" "$c" "$v" "$RESET"; }
system_info(){
 local os domain ip up users
 if [ -r /etc/os-release ]; then . /etc/os-release; os="${PRETTY_NAME:-${NAME:-Linux}}"; else os="$(uname -s 2>/dev/null || echo Linux)"; fi
 domain="$(cat /etc/xray/domain 2>/dev/null || hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
 ip="$(hostname -I 2>/dev/null | awk '{print $1}')"; [ -z "$ip" ]&&ip=unknown
 up="$(uptime -p 2>/dev/null | sed 's/^up //')"; [ -z "$up" ]&&up=unknown
 users="$(who 2>/dev/null | awk '{print $1}' | sort -u | sed '/^$/d' | wc -l)"
 box_title 'SYSTEM INFORMATION'; sysline 'OS' "$os" "$YELLOW"; sysline 'Domain' "$domain" "$CYAN"; sysline 'Uptime' "$up" "$GREEN"; sysline 'Online Users' "$users Connected" "$GREEN"; sysline 'IP Address' "$ip" "$BLUE"; printf '%b╰%s╯%b\n' "$GRAY" "$(repeat_char '─' $((W-2)))" "$RESET"; echo
}
header
box_title "SSH • OPENVPN"
system_info
item 1 "Create SSH & OpenVPN account" "$GREEN"
item 2 "Generate SSH & OpenVPN trial account" "$CYAN"
item 3 "Extend account active life" "$YELLOW"
item 4 "Check user login" "$BLUE"
item 5 "Member management" "$PURPLE"
item 6 "Delete SSH & OpenVPN account" "$RED"
item 7 "Delete expired users" "$RED"
item 8 "Configure SSH autokill" "$PURPLE"
item 9 "Display multi-login users" "$CYAN"
item 10 "Restart all services" "$YELLOW"
item 11 "Back to main menu" "$WHITE"
item 12 "Exit" "$RED"
footer 12
read -r menu
echo

case "$menu" in
1)
addssh
;;
2)
trialssh
;;
3)
renewssh
;;
4)
cekssh
;;
5)
member
;;
6)
delssh
;;
7)
delexp
;;
8)
autokill
;;
9)
ceklim
;;
10)
restart
;;
11)
clear; menu
;;
12)
clear; exit
;;
*)
  printf "%b\nInvalid selection. Please choose 1-12.%b\n" "$RED" "$RESET"; sleep 1; exec "$0"
;;
esac
