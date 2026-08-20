#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - shared premium terminal UI
RESET='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[38;5;51m'; GREEN='\033[38;5;46m'; BLUE='\033[38;5;39m'
PURPLE='\033[38;5;141m'; YELLOW='\033[38;5;226m'; RED='\033[38;5;203m'
WHITE='\033[38;5;255m'; GRAY='\033[38;5;245m'
UI_W=76
ui_repeat(){ local c="$1" n="$2" i; ((n<0))&&n=0; for ((i=0;i<n;i++)); do printf '%s' "$c"; done; }
ui_plain_len(){ printf '%s' "$1" | sed $'s/\\033\\[[0-9;]*m//g' | wc -m; }
ui_center(){ local t="$1" p=$(( (UI_W-$(ui_plain_len "$t"))/2 )); ((p<0))&&p=0; printf '%*s%b\n' "$p" '' "$t"; }
ui_header(){
 clear 2>/dev/null || true; echo
 ui_center "${BOLD}${CYAN}★ MAHBOUB${WHITE} TUNNEL ${PURPLE}PREMIUM ★${RESET}"
 ui_center "${DIM}${WHITE}Fast ${CYAN}•${WHITE} Secure ${PURPLE}•${WHITE} Stable ${GREEN}•${WHITE} Unlimited${RESET}"
 echo
}
ui_title(){
 local t="$1"; local rem=$((UI_W-6-${#t})); ((rem<1))&&rem=1
 printf '%b╭─[ %b%s%b ]%s╮%b\n' "$PURPLE" "$CYAN" "$t" "$PURPLE" "$(ui_repeat '─' "$rem")" "$PURPLE"
}
ui_bottom(){ printf '%b╰%s╯%b\n' "$PURPLE" "$(ui_repeat '─' $((UI_W-2)))" "$RESET"; }
# Count real remote clients currently connected to services on this VPS.
# This deliberately does NOT use a hard-coded/demo value. It uses the kernel's
# connection table (ss) and counts unique remote IPs with ESTABLISHED TCP
# sessions. SSH/TTY sessions are included automatically when their socket is
# visible in ss. Xray/Trojan-Go behind nginx are represented by the client TCP
# connection to nginx.
ui_online_clients(){
 local established ips ports
 command -v ss >/dev/null 2>&1 || { printf '0'; return; }

 # Prefer ports exposed by this installation. These cover the common VPN/proxy
 # ports without counting unrelated outbound connections from the VPS.
 ports="22,80,443,8484"
 if [ -r /etc/ssh/sshd_config ]; then
   local ssh_ports
   ssh_ports="$(awk 'tolower($1)=="port" && $2 ~ /^[0-9]+$/ {print $2}' /etc/ssh/sshd_config 2>/dev/null | paste -sd, -)"
   [ -n "$ssh_ports" ] && ports="$ports,$ssh_ports"
 fi

 # Add listening TCP ports for local proxy/VPN services, while ignoring the
 # high ephemeral range so ordinary outbound traffic is never counted.
 local listen
 listen="$(ss -H -lnt 2>/dev/null | awk '{split($4,a,":"); p=a[length(a)]; if (p ~ /^[0-9]+$/ && p <= 65535) print p}' | sort -n -u | paste -sd, -)"
 [ -n "$listen" ] && ports="$ports,$listen"

 established="$(ss -H -tn state established 2>/dev/null)"
 [ -z "$established" ] && { printf '0'; return; }

 printf '%s\n' "$established" | awk -v ports="$ports" '
 BEGIN { split(ports,p,","); for(i in p) allowed[p[i]]=1 }
 {
   local=$4; remote=$5;
   n=split(local,a,":"); lp=a[n];
   n=split(remote,b,":"); rip=remote; sub(/:[^:]+$/, "", rip);
   if (allowed[lp] && rip !~ /^(127\.0\.0\.1|::1|0\.0\.0\.0)$/) clients[rip]=1;
 }
 END { for (ip in clients) count++; print count+0 }'
}

ui_info(){
 local os domain time up users ip
 if [ -r /etc/os-release ]; then . /etc/os-release; os="${PRETTY_NAME:-${NAME:-Linux}}"; else os="$(uname -s 2>/dev/null || echo Linux)"; fi
 domain="$(cat /etc/xray/domain 2>/dev/null || hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
 time="$(date '+%Y-%m-%d %H:%M:%S')"
 up="$(uptime -p 2>/dev/null | sed 's/^up //')"; [ -z "$up" ]&&up=unknown
 users="$(ui_online_clients)"
 ip="$(hostname -I 2>/dev/null | awk '{print $1}')"; [ -z "$ip" ]&&ip=unknown
 ui_title 'SYSTEM INFORMATION'
 printf '%b│  🐧  %-15s : %b%s%b\n' "$GRAY" 'OS' "$YELLOW" "$os" "$RESET"
 printf '%b│  🌐  %-15s : %b%s%b\n' "$GRAY" 'Domain' "$CYAN" "$domain" "$RESET"
 printf '%b│  ◷   %-15s : %b%s%b\n' "$GRAY" 'Time' "$YELLOW" "$time" "$RESET"
 printf '%b│  ◷   %-15s : %b%s%b\n' "$GRAY" 'Uptime' "$GREEN" "$up" "$RESET"
 printf '%b│  👥  %-15s : %b%s active%b\n' "$GRAY" 'Online Users' "$GREEN" "$users" "$RESET"
 printf '%b│  IP  %-15s : %b%s%b\n' "$GRAY" 'Address' "$BLUE" "$ip" "$RESET"
 ui_bottom; echo
}
ui_item(){ local n="$1" label="$2" icon="$3" c="${4:-$GREEN}"; printf '%b│   %b[%02d]%b  %-42s %b%s ›%b\n' "$GRAY" "$c" "$n" "$RESET" "$label" "$c" "$icon" "$RESET"; }
ui_prompt(){ local max="$1"; echo; printf '%b╭─[ %bSELECT OPTION%b ]%b%s╮\n' "$PURPLE" "$CYAN" "$PURPLE" "$RESET" "$(ui_repeat '─' $((UI_W-19)))"; printf '%b│%b  Choose an option [ %b1-%s%b ] : ' "$GRAY" "$RESET" "$GREEN" "$max" "$RESET"; }
ui_submenu(){ local title="$1"; ui_header; ui_title "$title"; ui_info; }
