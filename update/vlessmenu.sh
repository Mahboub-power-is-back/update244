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
echo -e "$y$(center_text '┌──────────────────────────────────────────┐')$wh"
echo -e "$y$(center_text '│            XRAYS VLESS MENU              │')$wh"
echo -e "$y$(center_text '└──────────────────────────────────────────┘')$wh"
echo
echo -e "$y  ┌───┬────────────────────────────────────────┐$wh"
echo -e "$y  │$yy 1 $y│  Create Account XRAYS Vless Websocket $y │$wh"
echo -e "$y  │$yy 2 $y│  Delete Account XRAYS Vless Websocket $y │$wh"
echo -e "$y  │$yy 3 $y│  Extend Account Active Life           $y │$wh"
echo -e "$y  │$yy 4 $y│  Check User Login XRAYS Vless         $y │$wh"
echo -e "$y  │$yy 5 $y│  Menu Utama                           $y │$wh"
echo -e "$y  │$yy 6 $y│  Exit                                 $y │$wh"
echo -e "$y  └───┴────────────────────────────────────────┘$wh"
echo
echo -e "$y$(center_text '┌──────────────────────────────────────────┐')$wh"
echo -e "$y$(center_text '│     Select From Options [ 1 - 6 ]        │')$wh"
echo -e "$y$(center_text '└──────────────────────────────────────────┘')$wh"
echo
read -p "$(echo -e "$y│ $whSelect option: $y")" menu
echo -e ""
case $menu in
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
clear
menu
;;
6)
clear
exit
;;
*)
clear
menu
;;
esac
