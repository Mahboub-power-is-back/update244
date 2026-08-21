#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo "ERROR: ui.sh not found"; exit 1; fi
ui_submenu 'TROJAN • XRAY'
ui_item 1 'Create Trojan account (WS / XHTTP / HTTP-UP / gRPC / TCP) (WS / XHTTP / HTTP-UP / gRPC / TCP) (WS / XHTTP / HTTP-UP / gRPC / TCP) (WS / XHTTP / HTTP-UP / gRPC / TCP)' '➕' "$GREEN"
ui_item 2 'Delete Trojan account' '✕' "$RED"
ui_item 3 'Extend Trojan account active life' '↻' "$YELLOW"
ui_item 4 'List Trojan accounts & credentials' '👥' "$CYAN"
ui_item 5 'Back to main menu' '‹' "$WHITE"
ui_item 6 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 6
read -r menu
echo
case "$menu" in
1)
addtrojan
;;
2)
deltrojan
;;
3)
renewtrojan
;;
4)
cektrojan
;;
5)
clear; menu
;;
6)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-6.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
