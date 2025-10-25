sudo cat > /usr/bin/menu <<'EOF'
#!/bin/bash
clear

# ========= COLORS =========
BLUE="\033[1;34m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
WHITE="\033[1;37m"
RED="\033[1;31m"
GRAY="\033[0;37m"
RESET="\033[0m"

# ========= SYSTEM INFO =========
OS=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
CPU=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
CORE=$(nproc)
CPU_USAGE=$(top -bn1 | awk '/Cpu\(s\)/ {print 100 - $8}' | cut -d. -f1)
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_PERCENT=$((RAM_USED * 100 / RAM_TOTAL))
UPTIME=$(uptime -p | sed 's/up //;s/,//g')
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
IP=$(curl -s ipv4.icanhazip.com)
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || cat /etc/v2ray/domain 2>/dev/null || echo "Not set")
DATE=$(TZ=UTC date +"%Y-%m-%d %H:%M:%S UTC")
SSH_ONLINE=$(who | grep 'pts/' | wc -l)
OVPN_ONLINE=0
[ -f /etc/openvpn/server/openvpn-status.log ] && OVPN_ONLINE=$(grep -c 'CLIENT_LIST' /etc/openvpn/server/openvpn-status.log)
TOTAL_ONLINE=$((SSH_ONLINE + OVPN_ONLINE))

# ========= BAR FUNCTION =========
bar() {
  local p=$1; local f=$((p/10)); local e=$((10-f))
  printf "["
  for ((i=0;i<f;i++)); do printf "■"; done
  for ((i=0;i<e;i++)); do printf " "; done
  printf "] %s%%" "$p"
}

# ========= HEADER =========
echo -e "${BLUE}┌──────────────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│           ${GREEN}Mahboub Server Dashboard${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────────────┘${RESET}"
echo ""

# ========= INFO =========
printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s${RESET}\n" "OS" "$OS"
printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s${RESET}\n" "CPU" "$CPU"
printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s${RESET}\n" "Cores" "$CORE"

# CPU BAR
printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s%%  " "CPU Load" "$CPU_USAGE"
bar "$CPU_USAGE"
echo ""

# RAM BAR
printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s MB / %s MB  " "RAM" "$RAM_USED" "$RAM_TOTAL"
bar "$RAM_PERCENT"
echo ""

printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s${RESET}\n" "Uptime" "$UPTIME"
printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s${RESET}\n" "Load" "$LOAD"
printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s${RESET}\n" "IP" "$IP"
printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s${RESET}\n" "Domain" "$DOMAIN"
printf "${YELLOW}%-10s${WHITE}: ${GREEN}SSH:$SSH_ONLINE | OVPN:$OVPN_ONLINE | Total:$TOTAL_ONLINE${RESET}\n" "Online"
printf "${YELLOW}%-10s${WHITE}: ${GREEN}%s${RESET}\n" "Date" "$DATE"
echo -e "${CYAN}──────────────────────────────────────────────────────────────${RESET}"
echo ""

# ========= MENU =========
echo -e "${WHITE}[1]${RESET}  SSH & OpenVPN MENU"
echo -e "${WHITE}[2]${RESET}  L2TP MENU"
echo -e "${WHITE}[3]${RESET}  PPTP MENU"
echo -e "${WHITE}[4]${RESET}  SSTP MENU"
echo -e "${WHITE}[5]${RESET}  WIREGUARD MENU"
echo -e "${WHITE}[6]${RESET}  SHADOWSOCKS MENU"
echo -e "${WHITE}[7]${RESET}  SHADOWSOCKSR MENU"
echo -e "${WHITE}[8]${RESET}  VMESS MENU"
echo -e "${WHITE}[9]${RESET}  VLESS MENU"
echo -e "${WHITE}[10]${RESET} TROJAN GFW MENU"
echo -e "${WHITE}[11]${RESET} TROJAN GO MENU"
echo -e "${WHITE}[12]${RESET} SETTINGS MENU"
echo -e "${RED}[13]${RESET} EXIT"
echo ""
echo -e "${CYAN}──────────────────────────────────────────────────────────────${RESET}"
echo ""
read -p "Select an option [1-13]: " menu

# ========= ACTIONS =========
case $menu in
1) clear; sshovpnmenu ;;
2) clear; l2tpmenu ;;
3) clear; pptpmenu ;;
4) clear; sstpmenu ;;
5) clear; wgmenu ;;
6) clear; ssmenu ;;
7) clear; ssrmenu ;;
8) clear; vmessmenu ;;
9) clear; vlessmenu ;;
10) clear; trmenu ;;
11) clear; trgomenu ;;
12) clear; setmenu ;;
13) clear; exit ;;
*) clear; /usr/bin/menu ;;
esac
EOF

sudo chmod +x /usr/bin/menu
