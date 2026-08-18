#!/bin/bash

# ============================================================
#                  MAHBOUB VPN - SETUP
#          Ubuntu / Debian Installation Script
# ============================================================

if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root"
    exit 1
fi

clear

# ============================================================
# COLORS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# REPOSITORY
# ============================================================

BASE="https://raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main"

SSH="$BASE/ssh"
SSTP="$BASE/sstp"
SSR="$BASE/ssr"
SS="$BASE/shadowsocks"
WG="$BASE/wireguard"
XRAY="$BASE/xray"
IPSEC="$BASE/ipsec"
BACKUP="$BASE/backup"
WS="$BASE/websocket"
OHP="$BASE/ohp"
TRGO="$BASE/trojango"

LOG="/root/log-install.txt"
ERROR_LOG="/root/install-error.log"

# ============================================================
# LOGGING
# ============================================================

touch "$LOG" "$ERROR_LOG"

exec > >(tee -a "$LOG") 2> >(tee -a "$ERROR_LOG" >&2)

trap 'echo -e "${RED}[ERROR]${NC} Command failed at line $LINENO: $BASH_COMMAND"; echo "[ERROR] $(date) line $LINENO: $BASH_COMMAND" >> "$ERROR_LOG"' ERR

echo
echo "============================================================"
echo "              AKBAR VPN INSTALLER"
echo "============================================================"
echo

# ============================================================
# VPS CHECK
# ============================================================

echo -e "${CYAN}[INFO]${NC} Checking VPS..."

MYIP=$(curl -4 -fsSL --max-time 10 https://ipinfo.io/ip 2>/dev/null || true)

echo "Public IP : ${MYIP:-Unknown}"

if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT=$(systemd-detect-virt || true)

    if [ "$VIRT" = "openvz" ]; then
        echo -e "${RED}[ERROR]${NC} OpenVZ is not supported"
        exit 1
    fi
fi

# ============================================================
# PACKAGE MANAGER
# ============================================================

echo -e "${CYAN}[INFO]${NC} Checking package manager..."

export DEBIAN_FRONTEND=noninteractive

# Wait for another apt/dpkg process instead of fighting it
wait_for_apt() {
    local timeout=600
    local elapsed=0

    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
       || fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
       || fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do

        if [ "$elapsed" -ge "$timeout" ]; then
            echo -e "${RED}[ERROR]${NC} Package manager remained locked for ${timeout}s"
            return 1
        fi

        echo -e "${YELLOW}[WAIT]${NC} Another apt/dpkg process is running..."
        sleep 5
        elapsed=$((elapsed + 5))
    done

    return 0
}

wait_for_apt || exit 1

# Repair interrupted package operations
dpkg --configure -a || true

wait_for_apt || exit 1

apt-get update -y

# ============================================================
# BASIC DEPENDENCIES
# ============================================================

echo -e "${CYAN}[INFO]${NC} Installing basic dependencies..."

wait_for_apt || exit 1

apt-get install -y \
    curl \
    wget \
    ca-certificates \
    unzip \
    zip \
    tar \
    gzip \
    xz-utils \
    socat \
    cron \
    bash-completion \
    openssl \
    gnupg \
    gnupg2 \
    lsb-release \
    dnsutils \
    iptables \
    iptables-persistent \
    netfilter-persistent \
    screen \
    jq \
    lsof \
    procps \
    systemd \
    chrony \
    python3 \
    sed \
    grep \
    gawk \
    coreutils

# ntpdate was removed from newer Ubuntu releases.
# Use ntpsec-ntpdate when available, but don't fail installation.
if apt-cache show ntpsec-ntpdate >/dev/null 2>&1; then
    apt-get install -y ntpsec-ntpdate || true
fi

# ============================================================
# TIME
# ============================================================

echo -e "${CYAN}[INFO]${NC} Configuring time synchronization..."

timedatectl set-timezone Asia/Jakarta 2>/dev/null || true
timedatectl set-ntp true 2>/dev/null || true

systemctl enable chrony 2>/dev/null || true
systemctl restart chrony 2>/dev/null || true

if command -v chronyc >/dev/null 2>&1; then
    chronyc -a makestep 2>/dev/null || true
fi

date

# ============================================================
# SERVER DIRECTORY
# ============================================================

mkdir -p /var/lib/akbarstorevpn

if [ ! -f /var/lib/akbarstorevpn/ipvps.conf ]; then
    echo "IP=$MYIP" > /var/lib/akbarstorevpn/ipvps.conf
else
    sed -i "s/^IP=.*/IP=$MYIP/" /var/lib/akbarstorevpn/ipvps.conf
fi

# ============================================================
# DOWNLOAD FUNCTION
# ============================================================

download_script() {
    local url="$1"
    local output="$2"

    echo -e "${CYAN}[DOWNLOAD]${NC} $output"

    if curl -fL --retry 3 --retry-delay 2 "$url" -o "$output"; then
        chmod +x "$output"
        echo -e "${GREEN}[OK]${NC} $output downloaded"
        return 0
    fi

    echo -e "${RED}[ERROR]${NC} Failed to download $url"
    return 1
}

run_script() {
    local script="$1"
    local session="$2"

    if [ ! -f "$script" ]; then
        echo -e "${RED}[ERROR]${NC} Missing $script"
        return 1
    fi

    chmod +x "$script"

    echo
    echo "============================================================"
    echo "Running: $script"
    echo "============================================================"

    screen -S "$session" -X quit >/dev/null 2>&1 || true

    screen -dmS "$session" bash -c "./$script; exit \$?"

    while screen -list | grep -q "\.${session}[[:space:]]"; do
        sleep 2
    done

    return 0
}

# ============================================================
# DOMAIN / CLOUDFLARE SETUP
# ============================================================

echo
echo "============================================================"
echo "                DOMAIN CONFIGURATION"
echo "============================================================"

download_script "$SSH/cf.sh" /root/cf.sh
./cf.sh

# ============================================================
# XRAY
# ============================================================

echo
echo "============================================================"
echo "                    XRAY INSTALL"
echo "============================================================"

download_script "$XRAY/ins-xray.sh" /root/ins-xray.sh

run_script /root/ins-xray.sh xray

# ============================================================
# SSH / OPENVPN
# ============================================================

echo
echo "============================================================"
echo "                 SSH / OPENVPN INSTALL"
echo "============================================================"

download_script "$SSH/ssh-vpn.sh" /root/ssh-vpn.sh
run_script /root/ssh-vpn.sh ssh-vpn

# ============================================================
# SSTP
# ============================================================

echo
echo "============================================================"
echo "                    SSTP INSTALL"
echo "============================================================"

download_script "$SSTP/sstp.sh" /root/sstp.sh
run_script /root/sstp.sh sstp

# ============================================================
# SSR
# ============================================================

echo
echo "============================================================"
echo "                     SSR INSTALL"
echo "============================================================"

download_script "$SSR/ssr.sh" /root/ssr.sh
run_script /root/ssr.sh ssr

# ============================================================
# SHADOWSOCKS
# ============================================================

echo
echo "============================================================"
echo "                 SHADOWSOCKS INSTALL"
echo "============================================================"

download_script "$SS/sodosok.sh" /root/sodosok.sh
run_script /root/sodosok.sh shadowsocks

# ============================================================
# WIREGUARD
# ============================================================

echo
echo "============================================================"
echo "                  WIREGUARD INSTALL"
echo "============================================================"

download_script "$WG/wg.sh" /root/wg.sh
run_script /root/wg.sh wireguard

# ============================================================
# IPSEC / L2TP / PPTP
# ============================================================

echo
echo "============================================================"
echo "                 IPSEC / L2TP INSTALL"
echo "============================================================"

download_script "$IPSEC/ipsec.sh" /root/ipsec.sh
run_script /root/ipsec.sh ipsec

# ============================================================
# BACKUP / BRIDGE
# ============================================================

echo
echo "============================================================"
echo "                 BACKUP / BRIDGE SETUP"
echo "============================================================"

download_script "$BACKUP/set-br.sh" /root/set-br.sh
./set-br.sh

# ============================================================
# WEBSOCKET
# ============================================================

echo
echo "============================================================"
echo "                  WEBSOCKET INSTALL"
echo "============================================================"

download_script "$WS/edu.sh" /root/edu.sh
./edu.sh

# ============================================================
# OHP
# ============================================================

echo
echo "============================================================"
echo "                    OHP INSTALL"
echo "============================================================"

download_script "$OHP/ohp.sh" /root/ohp.sh
./ohp.sh

# ============================================================
# TROJAN-GO MENU SUPPORT
# ============================================================

echo
echo "============================================================"
echo "                  TROJAN-GO SUPPORT"
echo "============================================================"

# Download account-management scripts if available.
download_script "$TRGO/addtrgo.sh" /root/addtrgo.sh || true
download_script "$TRGO/cektrgo.sh" /root/cektrgo.sh || true
download_script "$TRGO/deltrgo.sh" /root/deltrgo.sh || true
download_script "$TRGO/renewtrgo.sh" /root/renewtrgo.sh || true

# ============================================================
# AUTO SETTINGS SERVICE
# ============================================================

echo
echo "============================================================"
echo "                 AUTO SETTINGS SERVICE"
echo "============================================================"

cat > /etc/systemd/system/autosett.service <<'EOF'
[Unit]
Description=Akbar VPN Auto Settings
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/set.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

download_script "$SSH/set.sh" /etc/set.sh || true

chmod +x /etc/set.sh 2>/dev/null || true

systemctl daemon-reload
systemctl enable autosett.service
systemctl start autosett.service || true

# ============================================================
# CLEANUP
# ============================================================

rm -f /root/ssh-vpn.sh
rm -f /root/sstp.sh
rm -f /root/wg.sh
rm -f /root/sodosok.sh
rm -f /root/ss.sh
rm -f /root/ssr.sh
rm -f /root/ins-xray.sh
rm -f /root/ipsec.sh
rm -f /root/set-br.sh
rm -f /root/edu.sh
rm -f /root/ohp.sh

# ============================================================
# VERSION
# ============================================================

echo "2.0" > /home/ver

# ============================================================
# INSTALLATION INFORMATION
# ============================================================

echo
echo "============================================================"
echo "              INSTALLATION COMPLETED"
echo "============================================================"
echo

echo "Xray TLS port : 8443"
echo "Xray HTTP port: 80"
echo "Xray Reality  : configured by ins-xray.sh"
echo "Xhttp         : configured by ins-xray.sh"
echo "WebSocket     : configured by ins-xray.sh"
echo "gRPC          : configured by ins-xray.sh"
echo "Trojan-Go     : configured by ins-xray.sh"
echo

echo "------------------------------------------------------------"
echo "SERVICE PORTS"
echo "------------------------------------------------------------"

echo "OpenSSH                 : 22, 443"
echo "OpenVPN                 : 1194, 2200, 990"
echo "Stunnel5                : 443, 445, 777"
echo "Dropbear                : 443, 109, 143"
echo "Squid                   : 3128, 8080"
echo "BadVPN                  : 7100, 7200, 7300"
echo "Nginx                   : 89"
echo "WireGuard               : 7070"
echo "L2TP/IPSEC              : 1701"
echo "PPTP                    : 1732"
echo "SSTP                    : 444"
echo "Shadowsocks-R           : 1443-1543"
echo "SS-OBFS TLS             : 2443-2543"
echo "SS-OBFS HTTP            : 3443-3543"
echo "Xray TLS                : 8443"
echo "Xray HTTP               : 80"
echo "WebSocket TLS           : 443"
echo "WebSocket None TLS      : 8880"
echo "WebSocket OpenVPN       : 2086"
echo "Trojan-Go               : 2087"
echo "OHP SSH                 : 8181"
echo "OHP Dropbear            : 8282"
echo "OHP OpenVPN             : 8383"

echo
echo "------------------------------------------------------------"
echo "SERVER INFORMATION"
echo "------------------------------------------------------------"

echo "Public IP               : $MYIP"
echo "Timezone                : Asia/Jakarta"
echo "Fail2Ban                : ON"
echo "IPTables                : ON"
echo "Auto-Reboot             : ON"
echo "IPv6                    : OFF"
echo "Auto Backup             : ON"
echo "Restore Data            : ON"
echo "Auto Delete Expired     : ON"
echo "White Label             : ON"

echo
echo "------------------------------------------------------------"
echo "LOG FILES"
echo "------------------------------------------------------------"

echo "Installation log : $LOG"
echo "Error log        : $ERROR_LOG"

echo
echo -e "${GREEN}Installation finished.${NC}"
echo -e "${YELLOW}Review $ERROR_LOG if any component failed.${NC}"
echo

# ============================================================
# FINAL SERVICE CHECK
# ============================================================

echo "============================================================"
echo "                 SERVICE STATUS"
echo "============================================================"

for service in xray trojan-go nginx chrony autosett; do
    if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}[RUNNING]${NC} $service"
        else
            echo -e "${YELLOW}[STOPPED]${NC} $service"
        fi
    fi
done

echo
echo "============================================================"
echo "                  MAHBOUB VPN READY"
echo "============================================================"
