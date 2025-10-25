#!/bin/bash                                                          clear
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
echo -e "$y$(center_text '│              SSH & OpenVPN               │')$wh"
echo -e "$y$(center_text '└──────────────────────────────────────────┘')$wh"
echo
echo -e "$y  ┌───┬────────────────────────────────────────┐$wh"
echo -e "$y  │$yy 1 $y│  Create SSH & OpenVPN Account         $y │$wh"
echo -e "$y  │$yy 2 $y│  Generate SSH & OpenVPN Trial Account $y │$wh"
echo -e "$y  │$yy 3 $y│  Extending Account Active Life        $y │$wh"
echo -e "$y  │$yy 4 $y│  Check User Login SSH & OpenVPN       $y │$wh"
echo -e "$y  │$yy 5 $y│  Daftar Member SSH & OpenVPN          $y │$wh"
echo -e "$y  │$yy 6 $y│  Delete SSH & OpenVPN Account         $y │$wh"
echo -e "$y  │$yy 7 $y│  Delete User Expired SSH & OpenVPN    $y │$wh"
echo -e "$y  │$yy 8 $y│  Set up Autokill SSH                  $y │$wh"
echo -e "$y  │$yy 9 $y│  Displays Multi Login Users           $y │$wh"
echo -e "$y  │$yy 10$y│  Restart All Service                  $y │$wh"
echo -e "$y  │$yy 11$y│  Menu Utama                           $y │$wh"
echo -e "$y  │$yy 12$y│  Exit                                 $y │$wh"
echo -e "$y  └───┴────────────────────────────────────────┘$wh"
echo
echo -e "$y$(center_text '┌──────────────────────────────────────────┐')$wh"
echo -e "$y$(center_text '│   Select From Options [ 1 - 12 ]         │')$wh"
echo -e "$y$(center_text '└──────────────────────────────────────────┘')$wh"
echo
read -p "$(echo -e "$y│ $whSelect option: $y")" menu
echo -e ""
case $menu in
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
menu
;;
12)
clear
exit
;;
*)
clear
menu
;;
esac
