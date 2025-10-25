#!/bin/bash
# ==========================
# XRAYS VLESS Management Menu
# ==========================

# Colors
m="\033[0;1;36m"
y="\033[0;1;37m"
yy="\033[0;1;32m"
yl="\033[0;1;33m"
r="\033[0;1;31m"
wh="\033[0m"

# Function to show menu
show_menu() {
    clear
    echo -e "${y}============================================================${wh}"
    echo -e "${y}                       XRAYS VLESS MENU                     ${wh}"
    echo -e "${y}============================================================${wh}"
    echo -e "${yy} 1${y}. Create Account XRAYS Vless Websocket"
    echo -e "${yy} 2${y}. Delete Account XRAYS Vless Websocket"
    echo -e "${yy} 3${y}. Extend Account XRAYS Vless Active Life"
    echo -e "${yy} 4${y}. Check User Login XRAYS Vless"
    echo -e "${yy} 5${y}. Main Menu"
    echo -e "${yy} 6${y}. Exit"
    echo -e "${y}============================================================${wh}"
    echo ""
}

# Wrapper functions (replace with actual commands)
addvless() {
    echo -e "${m}[INFO]${wh} Creating XRAYS VLESS account..."
}
delvless() {
    echo -e "${m}[INFO]${wh} Deleting XRAYS VLESS account..."
}
renewvless() {
    echo -e "${m}[INFO]${wh} Extending XRAYS VLESS account..."
}
cekvless() {
    echo -e "${m}[INFO]${wh} Checking XRAYS VLESS user login..."
}

# Main loop
while true; do
    show_menu
    read -p "Select From Options [1-6]: " menu
    echo ""
    case $menu in
        1)
            addvless
            read -p "Press Enter to return to menu..."
            ;;
        2)
            delvless
            read -p "Press Enter to return to menu..."
            ;;
        3)
            renewvless
            read -p "Press Enter to return to menu..."
            ;;
        4)
            cekvless
            read -p "Press Enter to return to menu..."
            ;;
        5)
            echo -e "${yl}Returning to main menu...${wh}"
            sleep 1
            ;;
        6)
            echo -e "${yl}Exiting...${wh}"
            sleep 1
            clear
            exit 0
            ;;
        *)
            echo -e "${r}[ERROR]${wh} Invalid option! Please select 1-6."
            sleep 1
            ;;
    esac
