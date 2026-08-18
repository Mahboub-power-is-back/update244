#!/bin/bash

# ============================================================
# MAHBOUB VPN - SETUP INSTALLER
# Original installation flow preserved
# Ubuntu / Debian compatible
# ============================================================

set +e

# ============================================================
# ROOT CHECK
# ============================================================

if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root"
    exit 1
fi

if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT=$(systemd-detect-virt 2>/dev/null)
    if [ "$VIRT" = "openvz" ]; then
        echo "OpenVZ is not supported"
        exit 1
    fi
fi

# ============================================================
# COLORS
# ============================================================

RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'

# ============================================================
# LOGGING
# ============================================================

LOG_DIR="/var/log/akbar-vpn"
LOG_FILE="$LOG_DIR/install.log"
ERROR_LOG="$LOG_DIR/error.log"

mkdir -p "$LOG_DIR"

touch "$LOG_FILE"
touch "$ERROR_LOG"

chmod 600 "$LOG_FILE" "$ERROR_LOG"

exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$ERROR_LOG" >&2)

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo
echo "============================================================"
echo "              AKBAR VPN INSTALLER"
echo "============================================================"
echo "Start Time : $START_TIME"
echo "Log File   : $LOG_FILE"
echo "Error Log  : $ERROR_LOG"
echo "============================================================"
echo

# ============================================================
# HOSTING LINKS
# ============================================================

akbarvpn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/ssh"
akbarvpnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/sstp"
akbarvpnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/ssr"
akbarvpnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/shadowsocks"
akbarvpnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/wireguard"
akbarvpnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/xray"
akbarvpnnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/ipsec"
akbarvpnnnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/backup"
akbarvpnnnnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/websocket"
akbarvpnnnnnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/ohp"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

warn() {
    echo -e "${ORANGE}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================
# APT LOCK HANDLING
# ============================================================

wait_for_apt() {

    info "Checking package manager..."

    local timeout=300
    local elapsed=0

    while fuser \
        /var/lib/dpkg/lock-frontend \
        /var/lib/dpkg/lock \
        /var/cache/apt/archives/lock \
        >/dev/null 2>&1
    do

        if [ "$elapsed" -ge "$timeout" ]; then
            error "APT/DPKG lock timeout."
            return 1
        fi

        echo -ne "\r${ORANGE}[WAIT]${NC} Another package process is running... ${elapsed}s"
        sleep 2

        elapsed=$((elapsed + 2))
    done

    echo
    ok "Package manager ready"

    return 0
}

# ============================================================
# PACKAGE INSTALLER
# ============================================================

install_packages() {

    wait_for_apt || return 1

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y

    wait_for_apt || return 1

    apt-get install -y \
        wget \
        curl \
        ca-certificates \
        gnupg \
        gnupg2 \
        lsb-release \
        dnsutils \
        unzip \
        zip \
        socat \
        cron \
        bash-completion \
        screen \
        iptables \
        iptables-persistent \
        netfilter-persistent \
        openssl \
        jq \
        lsof \
        psmisc \
        tar \
        gzip \
        xz-utils \
        chrony \
        openssh-client

    if [ $? -ne 0 ]; then
        error "Basic dependency installation failed."
        return 1
    fi

    # ntpdate was removed from newer Ubuntu/Debian.
    # Use ntpsec-ntpdate when available.
    if apt-cache show ntpdate >/dev/null 2>&1; then
        apt-get install -y ntpdate
    elif apt-cache show ntpsec-ntpdate >/dev/null 2>&1; then
        apt-get install -y ntpsec-ntpdate
    else
        warn "ntpdate package unavailable. Chrony will be used."
    fi

    ok "Basic dependencies installed"

    return 0
}

# ============================================================
# SAFE DOWNLOAD
# ============================================================

download_script() {

    local URL="$1"
    local FILE="$2"

    info "Downloading $FILE"

    rm -f "$FILE"

    if ! wget \
        --timeout=30 \
        --tries=3 \
        --retry-connrefused \
        -q \
        -O "$FILE" \
        "https://$URL"
    then
        error "Download failed: $URL"
        return 1
    fi

    if [ ! -s "$FILE" ]; then
        error "Downloaded file is empty: $FILE"
        return 1
    fi

    chmod +x "$FILE"

    ok "Downloaded $FILE"

    return 0
}

# ============================================================
# RUN SCRIPT
# ============================================================

run_script() {

    local FILE="$1"
    local NAME="$2"

    if [ ! -f "$FILE" ]; then
        error "$FILE does not exist"
        return 1
    fi

    chmod +x "$FILE"

    section "$NAME"

    bash "$FILE"

    local RC=$?

    if [ "$RC" -eq 0 ]; then
        ok "$NAME completed"
    else
        error "$NAME returned exit code $RC"
    fi

    return "$RC"
}

# ============================================================
# VPS INFORMATION
# ============================================================

section "VPS CHECK"

MYIP=$(curl -4 -fsSL --max-time 15 https://ipinfo.io/ip 2>/dev/null)

if [ -z "$MYIP" ]; then
    MYIP=$(wget -qO- -T 15 https://ipinfo.io/ip 2>/dev/null)
fi

echo "Public IP : ${MYIP:-UNKNOWN}"

if [ -z "$MYIP" ]; then
    warn "Could not determine public IPv4 address."
else
    ok "VPS detected"
fi

# ============================================================
# EXISTING INSTALLATION CHECK
# ============================================================

if [ -f "/etc/xray/domain" ]; then

    warn "Xray domain file already exists."
    echo
    echo "Existing installation detected."
    echo
    echo "If you want to reinstall, remove the existing installation"
    echo "only after making a backup."
    echo
    exit 0
fi

# ============================================================
# CREATE DIRECTORIES
# ============================================================

section "PREPARING SYSTEM"

mkdir -p /var/lib/akbarstorevpn
mkdir -p /var/log/akbar-vpn

cat > /var/lib/akbarstorevpn/ipvps.conf <<EOF
IP=${MYIP}
EOF

ok "Directories prepared"

# ============================================================
# INSTALL DEPENDENCIES
# ============================================================

section "INSTALLING DEPENDENCIES"

install_packages

if [ $? -ne 0 ]; then
    error "Failed to install dependencies."
    echo
    echo "See:"
    echo "  $LOG_FILE"
    echo "  $ERROR_LOG"
    exit 1
fi

# ============================================================
# CF / DOMAIN
# ============================================================

section "DOMAIN / CLOUDFLARE"

download_script "$akbarvpn/cf.sh" "/root/cf.sh"

if [ $? -eq 0 ]; then
    run_script "/root/cf.sh" "Cloudflare / Domain Setup"
else
    error "cf.sh could not be downloaded."
    exit 1
fi

# ============================================================
# XRAY
# ============================================================

section "XRAY"

download_script "$akbarvpnnnnnn/ins-xray.sh" "/root/ins-xray.sh"

if [ $? -eq 0 ]; then

    screen -S xray -X quit >/dev/null 2>&1 || true

    screen -dmS xray bash -c \
        "bash /root/ins-xray.sh >> '$LOG_FILE' 2>> '$ERROR_LOG'; echo \$? > /tmp/akbar-xray.rc"

    info "Xray installer started in screen session: xray"

    while [ ! -f /tmp/akbar-xray.rc ]; do
        sleep 2
    done

    XRAY_RC=$(cat /tmp/akbar-xray.rc)
    rm -f /tmp/akbar-xray.rc

    if [ "$XRAY_RC" = "0" ]; then
        ok "Xray installation completed"
    else
        error "Xray installation failed with code $XRAY_RC"
    fi

else
    error "Unable to download ins-xray.sh"
    exit 1
fi

# ============================================================
# SSH / OPENVPN
# ============================================================

section "SSH / OPENVPN"

download_script "$akbarvpn/ssh-vpn.sh" "/root/ssh-vpn.sh"

if [ $? -eq 0 ]; then
    screen -S ssh-vpn -X quit >/dev/null 2>&1 || true

    screen -dmS ssh-vpn bash -c \
        "bash /root/ssh-vpn.sh >> '$LOG_FILE' 2>> '$ERROR_LOG'; echo \$? > /tmp/akbar-ssh.rc"

    info "SSH/OpenVPN installer started."

    while [ ! -f /tmp/akbar-ssh.rc ]; do
        sleep 2
    done

    SSH_RC=$(cat /tmp/akbar-ssh.rc)
    rm -f /tmp/akbar-ssh.rc

    [ "$SSH_RC" = "0" ] && ok "SSH/OpenVPN completed" || error "SSH/OpenVPN failed"
else
    error "Unable to download ssh-vpn.sh"
fi

# ============================================================
# SSTP
# ============================================================

section "SSTP"

download_script "$akbarvpnn/sstp.sh" "/root/sstp.sh"

if [ $? -eq 0 ]; then

    screen -S sstp -X quit >/dev/null 2>&1 || true

    screen -dmS sstp bash -c \
        "bash /root/sstp.sh >> '$LOG_FILE' 2>> '$ERROR_LOG'; echo \$? > /tmp/akbar-sstp.rc"

    while [ ! -f /tmp/akbar-sstp.rc ]; do
        sleep 2
    done

    SSTP_RC=$(cat /tmp/akbar-sstp.rc)
    rm -f /tmp/akbar-sstp.rc

    [ "$SSTP_RC" = "0" ] && ok "SSTP completed" || error "SSTP failed"
else
    error "Unable to download sstp.sh"
fi

# ============================================================
# SSR
# ============================================================

section "SHADOWSOCKS-R"

download_script "$akbarvpnnn/ssr.sh" "/root/ssr.sh"

if [ $? -eq 0 ]; then

    screen -S ssr -X quit >/dev/null 2>&1 || true

    screen -dmS ssr bash -c \
        "bash /root/ssr.sh >> '$LOG_FILE' 2>> '$ERROR_LOG'; echo \$? > /tmp/akbar-ssr.rc"

    while [ ! -f /tmp/akbar-ssr.rc ]; do
        sleep 2
    done

    SSR_RC=$(cat /tmp/akbar-ssr.rc)
    rm -f /tmp/akbar-ssr.rc

    [ "$SSR_RC" = "0" ] && ok "SSR completed" || error "SSR failed"
else
    error "Unable to download ssr.sh"
fi

# ============================================================
# SHADOWSOCKS
# ============================================================

section "SHADOWSOCKS"

download_script "$akbarvpnnnn/sodosok.sh" "/root/sodosok.sh"

if [ $? -eq 0 ]; then

    screen -S ss -X quit >/dev/null 2>&1 || true

    screen -dmS ss bash -c \
        "bash /root/sodosok.sh >> '$LOG_FILE' 2>> '$ERROR_LOG'; echo \$? > /tmp/akbar-ss.rc"

    while [ ! -f /tmp/akbar-ss.rc ]; do
        sleep 2
    done

    SS_RC=$(cat /tmp/akbar-ss.rc)
    rm -f /tmp/akbar-ss.rc

    [ "$SS_RC" = "0" ] && ok "Shadowsocks completed" || error "Shadowsocks failed"
else
    error "Unable to download sodosok.sh"
fi

# ============================================================
# WIREGUARD
# ============================================================

section "WIREGUARD"

download_script "$akbarvpnnnnn/wg.sh" "/root/wg.sh"

if [ $? -eq 0 ]; then

    screen -S wg -X quit >/dev/null 2>&1 || true

    screen -dmS wg bash -c \
        "bash /root/wg.sh >> '$LOG_FILE' 2>> '$ERROR_LOG'; echo \$? > /tmp/akbar-wg.rc"

    while [ ! -f /tmp/akbar-wg.rc ]; do
        sleep 2
    done

    WG_RC=$(cat /tmp/akbar-wg.rc)
    rm -f /tmp/akbar-wg.rc

    [ "$WG_RC" = "0" ] && ok "WireGuard completed" || error "WireGuard failed"
else
    error "Unable to download wg.sh"
fi

# ============================================================
# L2TP / IPSEC
# ============================================================

section "L2TP / IPSEC"

download_script "$akbarvpnnnnnnn/ipsec.sh" "/root/ipsec.sh"

if [ $? -eq 0 ]; then

    screen -S ipsec -X quit >/dev/null 2>&1 || true

    screen -dmS ipsec bash -c \
        "bash /root/ipsec.sh >> '$LOG_FILE' 2>> '$ERROR_LOG'; echo \$? > /tmp/akbar-ipsec.rc"

    while [ ! -f /tmp/akbar-ipsec.rc ]; do
        sleep 2
    done

    IPSEC_RC=$(cat /tmp/akbar-ipsec.rc)
    rm -f /tmp/akbar-ipsec.rc

    [ "$IPSEC_RC" = "0" ] && ok "IPsec completed" || error "IPsec failed"
else
    error "Unable to download ipsec.sh"
fi

# ============================================================
# BACKUP / BRIDGE
# ============================================================

section "BACKUP / BRIDGE"

download_script "$akbarvpnnnnnnnn/set-br.sh" "/root/set-br.sh"

if [ $? -eq 0 ]; then
    run_script "/root/set-br.sh" "Bridge / Backup Setup"
else
    error "Unable to download set-br.sh"
fi

# ============================================================
# WEBSOCKET
# ============================================================

section "WEBSOCKET"

download_script "$akbarvpnnnnnnnnn/edu.sh" "/root/edu.sh"

if [ $? -eq 0 ]; then
    run_script "/root/edu.sh" "WebSocket Setup"
else
    error "Unable to download edu.sh"
fi

# ============================================================
# OHP
# ============================================================

section "OHP SERVER"

download_script "$akbarvpnnnnnnnnnn/ohp.sh" "/root/ohp.sh"

if [ $? -eq 0 ]; then
    run_script "/root/ohp.sh" "OHP Server"
else
    error "Unable to download ohp.sh"
fi

# ============================================================
# AUTO SETTING SERVICE
# ============================================================

section "AUTO SETTING"

cat > /etc/systemd/system/autosett.service <<'EOF'
[Unit]
Description=Akbar VPN Auto Setting
Documentation=https://t.me/Akbar218
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/set.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable autosett.service

wget -q \
    --timeout=30 \
    --tries=3 \
    -O /etc/set.sh \
    "https://${akbarvpn}/set.sh"

if [ -s /etc/set.sh ]; then
    chmod +x /etc/set.sh
    ok "Auto setting installed"
else
    error "Unable to download /etc/set.sh"
fi

# ============================================================
# CLEAN TEMPORARY INSTALLER FILES
# ============================================================

rm -f /root/ssh-vpn.sh
rm -f /root/sstp.sh
rm -f /root/wg.sh
rm -f /root/ss.sh
rm -f /root/sodosok.sh
rm -f /root/ssr.sh
rm -f /root/ins-xray.sh
rm -f /root/ipsec.sh
rm -f /root/set-br.sh
rm -f /root/edu.sh
rm -f /root/ohp.sh
rm -f /root/cf.sh

# ============================================================
# VERSION
# ============================================================

echo "1.2" > /home/ver

# ============================================================
# INSTALLATION SUMMARY
# ============================================================

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

section "INSTALLATION COMPLETE"

echo
echo "Start Time : $START_TIME"
echo "End Time   : $END_TIME"
echo
echo "Public IP  : ${MYIP:-UNKNOWN}"
echo
echo "Installation Log : $LOG_FILE"
echo "Error Log        : $ERROR_LOG"
echo

echo "============================================================"
echo "                  SERVICE & PORT"
echo "============================================================"

echo "OpenSSH                 : 443, 22"
echo "OpenVPN                 : TCP 1194, UDP 2200, SSL 990"
echo "Stunnel5                : 443, 445, 777"
echo "Dropbear                : 443, 109, 143"
echo "Squid Proxy             : 3128, 8080"
echo "Badvpn                  : 7100, 7200, 7300"
echo "Nginx                   : 89"
echo "Wireguard               : 7070"
echo "L2TP/IPSEC VPN          : 1701"
echo "PPTP VPN                : 1732"
echo "SSTP VPN                : 444"
echo "Shadowsocks-R           : 1443-1543"
echo "SS-OBFS TLS             : 2443-2543"
echo "SS-OBFS HTTP            : 3443-3543"
echo "XRAYS Vmess TLS         : 8443"
echo "XRAYS Vmess None TLS    : 80"
echo "XRAYS Vless TLS         : 8443"
echo "XRAYS Vless None TLS    : 80"
echo "XRAYS Trojan            : 8443"
echo "Websocket TLS           : 443"
echo "Websocket None TLS      : 8880"
echo "Websocket OVPN          : 2086"
echo "OHP SSH                 : 8181"
echo "OHP Dropbear            : 8282"
echo "OHP OpenVPN             : 8383"
echo "Trojan-Go               : 2087"
echo "UDP Custom              : 1-65535"

echo
echo "============================================================"
echo "               SERVER INFORMATION"
echo "============================================================"

echo "Timezone                : Asia/Jakarta"
echo "Fail2Ban                : [ON]"
echo "IPTables                : [ON]"
echo "Auto-Reboot             : [ON]"
echo "IPv6                    : [OFF]"
echo "Autoreboot              : 05:00 GMT +7"
echo "Autobackup Data"
echo "Restore Data"
echo "Auto Delete Expired Account"
echo "Full Orders For Various Services"
echo "White Label"

echo
echo "Installation Log --> $LOG_FILE"
echo "Error Log        --> $ERROR_LOG"
echo

# ============================================================
# FINISH
# ============================================================

echo "============================================================"
echo "                 AKBAR VPN READY"
echo "============================================================"
echo

ok "Installation process finished."

echo
echo "IMPORTANT:"
echo "If any service failed, check:"
echo
echo "  tail -n 100 $ERROR_LOG"
echo
echo "Full installation log:"
echo
echo "  less $LOG_FILE"
echo

# Preserve original behavior
echo "Reboot in 15 seconds..."

sleep 15

rm -f /root/setup.sh

reboot
