#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
[ -r "$BASE_DIR/ui.sh" ] && . "$BASE_DIR/ui.sh"
ui_submenu 'L2TP / IPSEC VPN'
ui_item 1 'Create L2TP account' '➕' "$GREEN"
ui_item 2 'Delete L2TP account' '✕' "$RED"
ui_item 3 'Extend L2TP account active life' '↻' "$YELLOW"
ui_item 4 'Back to main menu' '‹' "$WHITE"
ui_item 5 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 5
read -r menu
echo
case "$menu" in
1)
addl2tp
;;
2)
dell2tp
;;
3)
renewl2tp
;;
4)
clear; menu
;;
5)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-5.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
