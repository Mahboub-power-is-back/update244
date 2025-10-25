#!/bin/bash
# ==============================
# XRAYS VLESS Management Menu
# ==============================

# Colors
BLUE="\033[0;1;34m"
GREEN="\033[0;1;32m"
YELLOW="\033[0;1;33m"
RED="\033[0;1;31m"
WHITE="\033[0;1;37m"
RESET="\033[0m"

# Clear screen and show menu
clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}║                 XRAYS VLESS MANAGEMENT                 ║${RESET}"
echo -e "${BLUE}╠════════════════════════════════════════════════════════╣${RESET}"
echo -e "${YELLOW} 1)${WHITE} Create Account XRAYS Vless Websocket"
echo -e "${YELLOW} 2)${WHITE} Delete Account XRAYS Vless Websocket"
echo -e "${YELLOW} 3)${WHITE} Extend Account XRAYS Vless Active Life"
echo -e "${YELLOW} 4)${WHITE} Check User Login XRAYS Vless"
echo -e "${YELLOW} 5)${WHITE} Menu"
echo -e "${YELLOW} 6)${WHITE} Exit"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Read user input
read -p "Select From Options [1-6]: " menu
echo ""

# Call existing functions
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
