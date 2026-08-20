#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo "ERROR: ui.sh not found"; exit 1; fi
ui_submenu 'VLESS • XRAY'
ui_item 1 'Create VLESS WebSocket account' '➕' "$GREEN"
ui_item 2 'Delete VLESS WebSocket account' '✕' "$RED"
ui_item 3 'Extend VLESS account active life' '↻' "$YELLOW"
ui_item 4 'Check VLESS user login' '👥' "$CYAN"
ui_item 5 'Back to main menu' '‹' "$WHITE"
ui_item 6 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 6
read -r menu
echo
case "$menu" in
1)
addvless
;;
2)
delvless
;;
3)
renewvless
;;
4)
cekvless
;;
5)
clear; menu
;;
6)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-6.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
