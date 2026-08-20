#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo "ERROR: ui.sh not found"; exit 1; fi
ui_submenu 'PPTP VPN'
ui_item 1 'Create PPTP account' '➕' "$GREEN"
ui_item 2 'Delete PPTP account' '✕' "$RED"
ui_item 3 'Extend PPTP account active life' '↻' "$YELLOW"
ui_item 4 'Back to main menu' '‹' "$WHITE"
ui_item 5 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 5
read -r menu
echo
case "$menu" in
1)
addpptp
;;
2)
delpptp
;;
3)
renewpptp
;;
4)
clear; menu
;;
5)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-5.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
