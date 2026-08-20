#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
[ -r "$BASE_DIR/ui.sh" ] && . "$BASE_DIR/ui.sh"
ui_submenu 'WIREGUARD VPN'
ui_item 1 'Create WireGuard account' '➕' "$GREEN"
ui_item 2 'Delete WireGuard account' '✕' "$RED"
ui_item 3 'Extend WireGuard account active life' '↻' "$YELLOW"
ui_item 4 'Back to main menu' '‹' "$WHITE"
ui_item 5 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 5
read -r menu
echo
case "$menu" in
1)
addwg
;;
2)
delwg
;;
3)
renewwg
;;
4)
clear; menu
;;
5)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-5.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
