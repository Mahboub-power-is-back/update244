#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo "ERROR: ui.sh not found"; exit 1; fi
ui_submenu 'VMESS • XRAY'
ui_item 1 'Create VMess WebSocket account' '➕' "$GREEN"
ui_item 2 'Delete VMess WebSocket account' '✕' "$RED"
ui_item 3 'Extend VMess account active life' '↻' "$YELLOW"
ui_item 4 'Check VMess user login' '👥' "$CYAN"
ui_item 5 'Renew VMess certificate' '🔑' "$BLUE"
ui_item 6 'Back to main menu' '‹' "$WHITE"
ui_item 7 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 7
read -r menu
echo
case "$menu" in
1)
addvmess
;;
2)
delvmess
;;
3)
renewvmess
;;
4)
cekvmess
;;
5)
certv2ray
;;
6)
clear; menu
;;
7)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-7.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
