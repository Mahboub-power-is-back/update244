#!/bin/bash
# Color definitions
m="\033[0;1;36m"
y="\033[0;1;37m"
yy="\033[0;1;32m"
yl="\033[0;1;33m"
wh="\033[0m"

# Function to display centered text
center_text() {
    local text="$1"
    local width=50
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%${padding}s" ''
    echo -e "$text"
}

echo -e "$y$(center_text '┌──────────────────────────────────────────┐')$wh"
echo -e "$y$(center_text '│              WIREGUARD MENU              │')$wh"
echo -e "$y$(center_text '└──────────────────────────────────────────┘')$wh"
echo
echo -e "$y  ┌───┬────────────────────────────────────────┐$wh"
echo -e "$y  │$yy 1 $y│  Create Account Wireguard             $y │$wh"
echo -e "$y  │$yy 2 $y│  Delete Account Wireguard             $y │$wh"
echo -e "$y  │$yy 3 $y│  Extend Account Active Life           $y │$wh"
echo -e "$y  │$yy 4 $y│  Menu Utama                           $y │$wh"
echo -e "$y  │$yy 5 $y│  Exit                                 $y │$wh"
echo -e "$y  └───┴────────────────────────────────────────┘$wh"
echo
echo -e "$y$(center_text '┌──────────────────────────────────────────┐')$wh"
echo -e "$y$(center_text '│     Select From Options [ 1 - 5 ]        │')$wh"
echo -e "$y$(center_text '└──────────────────────────────────────────┘')$wh"
echo
read -p "$(echo -e "$y│ $whSelect option: $y")" menu
echo -e ""

case $menu in
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
clear
menu
;;
5)
clear
exit
;;
*)
clear
menu
;;
esac
