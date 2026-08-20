#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo "ERROR: ui.sh not found"; exit 1; fi
ui_submenu 'SHADOWSOCKS-R'
ui_item 1 'Create Shadowsocks-R account' '➕' "$GREEN"
ui_item 2 'Delete Shadowsocks-R account' '✕' "$RED"
ui_item 3 'Extend account active life' '↻' "$YELLOW"
ui_item 4 'Display Shadowsocks-R config' '◉' "$CYAN"
ui_item 5 'Back to main menu' '‹' "$WHITE"
ui_item 6 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 6
read -r menu
echo
case "$menu" in
1)
addssr
;;
2)
delssr
;;
3)
renewssr
;;
4)
ssr
;;
5)
clear; menu
;;
6)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-6.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
