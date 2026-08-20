#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo "ERROR: ui.sh not found"; exit 1; fi
ui_submenu 'SSH & OPENVPN'
ui_item 1 'Create SSH & OpenVPN account' '🔐' "$GREEN"
ui_item 2 'Create trial account' '⚡' "$CYAN"
ui_item 3 'Extend account active life' '↻' "$YELLOW"
ui_item 4 'Check user login' '👥' "$BLUE"
ui_item 5 'Member management' '👤' "$PURPLE"
ui_item 6 'Delete account' '✕' "$RED"
ui_item 7 'Delete expired users' '⌛' "$RED"
ui_item 8 'Configure SSH autokill' '🛡' "$PURPLE"
ui_item 9 'Display multi-login users' '👥' "$CYAN"
ui_item 10 'Restart all services' '↻' "$YELLOW"
ui_item 11 'Back to main menu' '‹' "$WHITE"
ui_item 12 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 12
read -r menu
echo
case "$menu" in
1)
addssh
;;
2)
trialssh
;;
3)
renewssh
;;
4)
cekssh
;;
5)
member
;;
6)
delssh
;;
7)
delexp
;;
8)
autokill
;;
9)
ceklim
;;
10)
restart
;;
11)
clear; menu
;;
12)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-12.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
