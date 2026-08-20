#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
[ -r "$BASE_DIR/ui.sh" ] && . "$BASE_DIR/ui.sh"
ui_submenu 'SHADOWSOCKS'
ui_item 1 'Create Shadowsocks account' '➕' "$GREEN"
ui_item 2 'Delete Shadowsocks account' '✕' "$RED"
ui_item 3 'Extend account active life' '↻' "$YELLOW"
ui_item 4 'Check user login' '👥' "$CYAN"
ui_item 5 'Back to main menu' '‹' "$WHITE"
ui_item 6 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 6
read -r menu
echo
case "$menu" in
1)
addss
;;
2)
delss
;;
3)
renewss
;;
4)
cekss
;;
5)
clear; menu
;;
6)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-6.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
