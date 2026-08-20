#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo "ERROR: ui.sh not found"; exit 1; fi
ui_submenu 'TROJAN GO'
ui_item 1 'Create Trojan-Go account' '➕' "$GREEN"
ui_item 2 'Delete Trojan-Go account' '✕' "$RED"
ui_item 3 'Extend Trojan-Go account active life' '↻' "$YELLOW"
ui_item 4 'Check Trojan-Go user login' '👥' "$CYAN"
ui_item 5 'Back to main menu' '‹' "$WHITE"
ui_item 6 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 6
read -r menu
echo
case "$menu" in
1)
addtrgo
;;
2)
deltrgo
;;
3)
renewtrgo
;;
4)
cektrgo
;;
5)
clear; menu
;;
6)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-6.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
