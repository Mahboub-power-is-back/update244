#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Main menu
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo 'ERROR: ui.sh not found'; exit 1; fi
if [ -r "$BASE_DIR/http_tunnel.sh" ]; then . "$BASE_DIR/http_tunnel.sh"; elif [ -r /usr/bin/http_tunnel.sh ]; then . /usr/bin/http_tunnel.sh; fi

ui_header
ui_info
ui_title 'MAIN MENU'

# Two balanced columns. Fixed widths keep the frame aligned on phone SSH clients.
ui_main_row 1  'SSH & OPENVPN'    '🔐' "$GREEN" 6  'SHADOWSOCKS'     '✈' "$PURPLE"
ui_main_row 2  'L2TP / IPSEC VPN' '🔒' "$YELLOW" 7  'SHADOWSOCKS-R'    '➤' "$CYAN"
ui_main_row 3  'PPTP VPN'         '🔒' "$YELLOW" 8  'VMESS (XRAY)'     'V' "$BLUE"
ui_main_row 4  'SSTP VPN'         '🛡' "$CYAN"   9  'VLESS (XRAY)'     'V' "$GREEN"
ui_main_row 5  'WIREGUARD VPN'    '●' "$RED"    10 'TROJAN (XRAY)'    'T' "$RED"

# Centered bottom items preserve the same visual hierarchy as the reference design.
printf '%b│%b%*s%b[%02d]%b  %-27s %b%s%b  %b›%b%*s%b│%b\n' \
    "$GRAY" "$RESET" 14 '' "$RED" 11 "$RESET" 'TROJAN GO' "$RED" 'T' "$RESET" "$GRAY" "$RESET" 14 '' "$GRAY" "$RESET"
printf '%b│%b%*s%b[%02d]%b  %-27s %b%s%b  %b›%b%*s%b│%b\n' \
    "$GRAY" "$RESET" 14 '' "$YELLOW" 12 "$RESET" 'SETTINGS' "$YELLOW" '⚙' "$RESET" "$GRAY" "$RESET" 14 '' "$GRAY" "$RESET"
printf '%b│%b%*s%b[%02d]%b  %-27s %b%s%b  %b›%b%*s%b│%b\n' \
    "$GRAY" "$RESET" 14 '' "$CYAN" 13 "$RESET" 'HTTP TUNNEL' "$CYAN" '⇄' "$RESET" "$GRAY" "$RESET" 14 '' "$GRAY" "$RESET"
printf '%b│%b%*s%b[%02d]%b  %-27s %b%s%b  %b›%b%*s%b│%b\n' \
    "$GRAY" "$RESET" 14 '' "$RED" 14 "$RESET" 'EXIT' "$RED" '⇥' "$RESET" "$GRAY" "$RESET" 14 '' "$GRAY" "$RESET"

ui_bottom
ui_prompt 14
read -r menu
echo
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
  13) clear; http_tunnel_menu ;;
  14) clear; exit 0 ;;
  *) printf '%b\nInvalid selection. Please choose 1-14.%b\n' "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
