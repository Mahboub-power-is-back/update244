#!/bin/bash
# Color definitions
m="\033[0;1;36m"  # Cyan
y="\033[0;1;37m"  # White
yy="\033[0;1;32m" # Green
yl="\033[0;1;33m" # Yellow
wh="\033[0m"      # Reset
# Function to display centered text
center_text() {
    local text="$1"
    local width=50
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%${padding}s" ''
    echo -e "$text"
}
echo -e "$y┌─────────────────────────────────────────────────────────────────┐$wh"
echo -e "$y│$m                       SYSTEM SETTINGS$y                           │$wh"
echo -e "$y├─────────────────────────────────────────────────────────────────┤$wh"
echo -e "$y│  $yy[01]$y ─ Add Or Change Subdomain Host For VPS$y                    │$wh"
echo -e "$y│  $yy[02]$y ─ Change Port Of Some Service$y                             │$wh"
echo -e "$y│  $yy[03]$y ─ Autobackup Data VPS$y                                     │$wh"
echo -e "$y│  $yy[04]$y ─ Backup Data VPS$y                                         │$wh"
echo -e "$y│  $yy[05]$y ─ Restore Data VPS$y                                        │$wh"
echo -e "$y│  $yy[06]$y ─ Webmin Menu$y                                             │$wh"
echo -e "$y│  $yy[07]$y ─ Limit Bandwidth Speed Server$y                            │$wh"
echo -e "$y│  $yy[08]$y ─ Check Usage of VPS Ram$y                                  │$wh"
echo -e "$y│  $yy[09]$y ─ Reboot VPS$y                                              │$wh"
echo -e "$y│  $yy[10]$y ─ Speedtest VPS$y                                           │$wh"
echo -e "$y│  $yy[11]$y ─ Displaying System Information$y                           │$wh"
echo -e "$y│  $yy[12]$y ─ Info Script Auto Install$y                                │$wh"
echo -e "$y│  $yy[13]$y ─ Main Menu$y                                               │$wh"
echo -e "$y│  $yy[14]$y ─ Exit$y                                                    │$wh"
echo -e "$y├─────────────────────────────────────────────────────────────────┤$wh"
echo -e "$y│$m                   Autoscript By : mahboub-million$y               │$wh"
echo -e "$y└─────────────────────────────────────────────────────────────────┘$wh"
echo
echo -e "$y$(center_text '┌──────────────────────────────────────────┐')$wh"
echo -e "$y$(center_text '│   Select From Options [ 1 - 14 ]         │')$wh"
echo -e "$y$(center_text '└──────────────────────────────────────────┘')$wh"
echo
read -p "$(echo -e "$y│ $whSelect option: $y")" menu
case $menu in
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
clear
menu
;;
14)
clear
exit
;;
*)
clear
echo -e "$yl❌  Invalid selection! Please try again.$wh"
sleep 2
setmenu
;;
esac
