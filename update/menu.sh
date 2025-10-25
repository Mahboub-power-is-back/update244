#!/bin/bash
clear

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
echo -e "$y$(center_text '│             MENU UTAMA                   │')$wh"
echo -e "$y$(center_text '└──────────────────────────────────────────┘')$wh"
echo
echo -e "$y  ┌───┬────────────────────────────────────────┐$wh"
echo -e "$y  │$yy 1 $y│  SSH & OpenVPN MENU                   $y │$wh"
echo -e "$y  │$yy 2 $y│  L2TP MENU                            $y │$wh"
echo -e "$y  │$yy 3 $y│  PPTP MENU                            $y │$wh"
echo -e "$y  │$yy 4 $y│  SSTP MENU                            $y │$wh"
echo -e "$y  │$yy 5 $y│  WIREGUARD MENU                       $y │$wh"
echo -e "$y  │$yy 6 $y│  SHADOWSOCKS MENU                     $y │$wh"
echo -e "$y  │$yy 7 $y│  SHADOWSOCKSR MENU                    $y │$wh"
echo -e "$y  │$yy 8 $y│  VMESS MENU                           $y │$wh"
echo -e "$y  │$yy 9 $y│  VLESS MENU                           $y │$wh"
echo -e "$y  │$yy 10$y│  TROJAN GFW MENU                      $y │$wh"
echo -e "$y  │$yy 11$y│  TROJAN GO MENU                       $y │$wh"
echo -e "$y  │$yy 12$y│  Settings                             $y │$wh"
echo -e "$y  │$yy 13$y│  Exit                                 $y │$wh"
echo -e "$y  └───┴────────────────────────────────────────┘$wh"
echo
echo -e "$y$(center_text '┌──────────────────────────────────────────┐')$wh"
echo -e "$y$(center_text '│   Select From Options [ 1 - 13 ]         │')$wh"
echo -e "$y$(center_text '└──────────────────────────────────────────┘')$wh"
echo
read -p "$(echo -e "$y│ $whSelect option: $y")" menu

case \$menu in
1)
clear
sshovpnmenu
;;
2)
clear
l2tpmenu
;;
3)
clear
pptpmenu
;;
4)
clear
sstpmenu
;;
5)
clear
wgmenu
;;
6)
clear
ssmenu
;;
7)
clear
ssrmenu
;;
8)
clear
vmessmenu
;;
9)
clear
vlessmenu
;;
10)
clear
trmenu
;;
11)
clear
trgomenu
;;
12)
clear
setmenu
;;
13)
clear
exit
;;
*)
clear
echo -e "\$yl Invalid selection. Please try again.\$wh"
sleep 2
menu
;;
esac
