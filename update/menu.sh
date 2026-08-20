#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Main menu
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo 'ERROR: ui.sh not found'; exit 1; fi

ui_header
ui_info
ui_title 'MAIN MENU'
printf '%b│%b  %b[01]%b  🔐 SSH & OPENVPN              %b[06]%b  ➤ SHADOWSOCKS%b│%b\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$PURPLE" "$RESET" "$PURPLE" "$RESET"
printf '%b│%b  %b[02]%b  🔒 L2TP / IPSEC VPN           %b[07]%b  ➤ SHADOWSOCKS-R%b│%b\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$CYAN" "$RESET" "$PURPLE" "$RESET"
printf '%b│%b  %b[03]%b  🔒 PPTP VPN                    %b[08]%b  V VMESS (XRAY)%b│%b\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$BLUE" "$RESET" "$PURPLE" "$RESET"
printf '%b│%b  %b[04]%b  🛡 SSTP VPN                    %b[09]%b  V VLESS (XRAY)%b│%b\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$PURPLE" "$RESET"
printf '%b│%b  %b[05]%b  ● WIREGUARD VPN                %b[10]%b  T TROJAN (XRAY)%b│%b\n' "$GRAY" "$RESET" "$GREEN" "$RESET" "$RED" "$RESET" "$PURPLE" "$RESET"
printf '%b│%b%*s%b[11]%b  ➤ TROJAN GO%b%*s│%b\n' "$GRAY" "" 27 "" "$RED" "$RESET" "$RED" 12 "" "$GRAY" 
printf '%b│%b%*s%b[12]%b  ⚙ SETTINGS%b%*s│%b\n' "$GRAY" "" 27 "" "$YELLOW" "$RESET" "$YELLOW" 12 "" "$GRAY" 
printf '%b│%b%*s%b[13]%b  ⇥ EXIT%b%*s│%b\n' "$GRAY" "" 27 "" "$RED" "$RESET" "$RED" 12 "" "$GRAY"
ui_bottom
ui_prompt 13
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
  13) clear; exit 0 ;;
  *) printf '%b\nInvalid selection. Please choose 1-13.%b\n' "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
