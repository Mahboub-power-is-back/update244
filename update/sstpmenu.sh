#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
[ -r "$BASE_DIR/ui.sh" ] && . "$BASE_DIR/ui.sh"
ui_submenu 'SSTP VPN'
ui_item 1 'Create SSTP account' '➕' "$GREEN"
ui_item 2 'Delete SSTP account' '✕' "$RED"
ui_item 3 'Extend SSTP account active life' '↻' "$YELLOW"
ui_item 4 'Check SSTP user login' '👥' "$CYAN"
ui_item 5 'Back to main menu' '‹' "$WHITE"
ui_item 6 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 6
read -r menu
echo
case "$menu" in
1)
addsstp
;;
2)
delsstp
;;
3)
renewsstp
;;
4)
ceksstp
;;
5)
clear; menu
;;
6)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-6.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
