#!/bin/bash
# MAHBOUB TUNNEL PREMIUM - Premium menu design
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -r "$BASE_DIR/ui.sh" ]; then . "$BASE_DIR/ui.sh"; elif [ -r /usr/bin/ui.sh ]; then . /usr/bin/ui.sh; else echo "ERROR: ui.sh not found"; exit 1; fi
ui_submenu 'SYSTEM SETTINGS'
ui_item 1 'Add / change subdomain host' '🌐' "$CYAN"
ui_item 2 'PORT SETTINGS' '⚙' "$YELLOW"
ui_item 3 'Autobackup VPS data' '▣' "$GREEN"
ui_item 4 'Backup VPS data' '▣' "$GREEN"
ui_item 5 'Restore VPS data' '↻' "$RED"
ui_item 6 'Webmin menu' '▣' "$BLUE"
ui_item 7 'Limit server bandwidth speed' '⇅' "$PURPLE"
ui_item 8 'Check VPS RAM usage' '◉' "$CYAN"
ui_item 9 'Reboot VPS' '↻' "$RED"
ui_item 10 'VPS speed test' '⚡' "$GREEN"
ui_item 11 'Display system information' 'ⓘ' "$WHITE"
ui_item 12 'About / auto-install info' 'ⓘ' "$CYAN"
ui_item 13 'Back to main menu' '‹' "$WHITE"
ui_item 14 'Exit' '⇥' "$RED"
ui_bottom
ui_prompt 14
read -r menu
echo
case "$menu" in
1)
addhost
;;
2)
changeport
;;
3)
autobackup
;;
4)
backup
;;
5)
restore
;;
6)
wbmn
;;
7)
limitspeed
;;
8)
ram
;;
9)
reboot
;;
10)
speedtest
;;
11)
info
;;
12)
about
;;
13)
clear; menu
;;
14)
clear; exit
;;
*) printf "%b\nInvalid selection. Please choose 1-14.%b\n" "$RED" "$RESET"; sleep 1; exec "$0" ;;
esac
