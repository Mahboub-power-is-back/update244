#!/bin/bash
# ============================================================
# MAHBOUB VPN - SETUP INSTALLER (MATCHED TO CORRECTED XRAY/SSH)
#
# Ubuntu / Debian
#
# IMPORTANT PORT OWNERSHIP
#   80/443/8443  -> Xray/HAProxy/Nginx multiplexer
#   /ssh         -> SSH WebSocket on 80/443/8443
#   /ovpn-ws     -> OpenVPN WebSocket on 80/443/8443
#   8880          -> SSH WebSocket backend
#   2086          -> OpenVPN WebSocket backend
#   2087          -> Trojan-Go
#   89            -> legacy Nginx panel
#
# This setup intentionally DOES NOT run the old edu.sh websocket
# installer because it can claim 443/8880 and undo the corrected
# Xray + SSH WebSocket layout.
#
# Other VPN services are installed on their own ports/ranges.
# ============================================================

set -Eeuo pipefail
IFS=$'\n\t'

[ "${EUID}" -eq 0 ] || { echo "Run this script as root."; exit 1; }

if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT="$(systemd-detect-virt 2>/dev/null || true)"
    [ "$VIRT" = "openvz" ] && { echo "OpenVZ is not supported."; exit 1; }
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

LOG_DIR="/var/log/akbar-vpn"
LOG_FILE="$LOG_DIR/install.log"
ERROR_LOG="$LOG_DIR/error.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE" "$ERROR_LOG"
chmod 600 "$LOG_FILE" "$ERROR_LOG"

exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$ERROR_LOG" >&2)

START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"

info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
section(){
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

wait_for_apt(){
    local timeout=600 elapsed=0
    while fuser /var/lib/dpkg/lock-frontend \
              /var/lib/dpkg/lock \
              /var/cache/apt/archives/lock >/dev/null 2>&1; do
        [ "$elapsed" -ge "$timeout" ] && return 1
        echo -ne "\r${YELLOW}[WAIT]${NC} APT/DPKG lock: ${elapsed}s"
        sleep 2
        elapsed=$((elapsed+2))
    done
    echo
    return 0
}

install_packages(){
    wait_for_apt || die "APT/DPKG lock timeout."
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y || die "apt update failed."

    wait_for_apt || die "APT/DPKG lock timeout."

    apt-get install -y \
        wget curl ca-certificates gnupg gnupg2 lsb-release \
        dnsutils unzip zip socat cron bash-completion screen \
        iptables iptables-persistent netfilter-persistent openssl jq \
        lsof psmisc tar gzip xz-utils chrony openssh-client \
        python3 python3-venv || die "Basic dependency installation failed."

    systemctl enable --now chrony 2>/dev/null || true
    timedatectl set-ntp true 2>/dev/null || true

    ok "Dependencies installed."
}

download_script(){
    local url="$1" file="$2"
    info "Downloading $file"
    rm -f "$file"
    curl -fL --retry 3 --connect-timeout 15 --max-time 180 \
        -o "$file" "https://$url" || {
        error "Download failed: $url"
        return 1
    }
    [ -s "$file" ] || { error "Empty download: $file"; return 1; }
    chmod 700 "$file"
    ok "Downloaded $file"
}

run_script(){
    local file="$1" name="$2"
    [ -f "$file" ] || { warn "$file not found; skipping $name."; return 0; }
    section "$name"
    bash "$file"
}

run_screened(){
    local file="$1" name="$2" session="$3" rcfile="$4"
    [ -f "$file" ] || { warn "$file not found; skipping $name."; return 0; }

    rm -f "$rcfile"
    screen -S "$session" -X quit >/dev/null 2>&1 || true

    screen -dmS "$session" bash -c \
        "bash '$file' >> '$LOG_FILE' 2>> '$ERROR_LOG'; echo \$? > '$rcfile'"

    while [ ! -s "$rcfile" ]; do sleep 2; done
    local rc
    rc="$(cat "$rcfile")"
    rm -f "$rcfile"

    if [ "$rc" = "0" ]; then
        ok "$name completed."
    else
        warn "$name returned exit code $rc. See $ERROR_LOG."
    fi
}

# ============================================================
# REPOSITORIES
# ============================================================

BASE="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main"

SSH_PATH="$BASE/ssh"
SSTP_PATH="$BASE/sstp"
SSR_PATH="$BASE/ssr"
SS_PATH="$BASE/shadowsocks"
WG_PATH="$BASE/wireguard"
XRAY_PATH="$BASE/xray"
IPSEC_PATH="$BASE/ipsec"
BACKUP_PATH="$BASE/backup"
OHP_PATH="$BASE/ohp"

# ============================================================
# START
# ============================================================

clear 2>/dev/null || true
echo "============================================================"
echo "              MAHBOUB VPN INSTALLER"
echo "============================================================"
echo "Start Time : $START_TIME"
echo "Log File   : $LOG_FILE"
echo "============================================================"

section "VPS CHECK"

MYIP="$(curl -4 -fsSL --max-time 15 https://api.ipify.org 2>/dev/null || true)"
[ -n "$MYIP" ] || MYIP="$(curl -4 -fsSL --max-time 15 https://ifconfig.me 2>/dev/null || true)"
echo "Public IP : ${MYIP:-UNKNOWN}"

mkdir -p /var/lib/akbarstorevpn
printf 'IP=%s\n' "${MYIP:-UNKNOWN}" > /var/lib/akbarstorevpn/ipvps.conf

section "DEPENDENCIES"
install_packages

# ============================================================
# DOMAIN / CLOUDFLARE
# ============================================================

section "DOMAIN / CLOUDFLARE"

download_script "$SSH_PATH/cf.sh" /root/cf.sh || die "cf.sh download failed."
run_script /root/cf.sh "Cloudflare / Domain Setup"

[ -s /etc/xray/domain ] || die "/etc/xray/domain was not created by cf.sh."
DOMAIN="$(head -n1 /etc/xray/domain | tr -d '[:space:]')"
[ -n "$DOMAIN" ] || die "Domain is empty."
ok "Domain: $DOMAIN"

# ============================================================
# XRAY
# ============================================================

section "XRAY"

download_script "$XRAY_PATH/ins-xray.sh" /root/ins-xray.sh \
    || die "Unable to download corrected ins-xray.sh."

run_screened /root/ins-xray.sh \
    "Corrected Xray installer" xray /tmp/akbar-xray.rc

# Xray is a required part of the 80/443/8443 multiplexer.
# Never continue to the remaining installers with a failed Xray stack.
if [ ! -s /etc/xray/config.json ] || ! /usr/local/bin/xray run -test -config /etc/xray/config.json >/tmp/akbar-xray-validation.log 2>&1; then
    cat /tmp/akbar-xray-validation.log 2>/dev/null || true
    die "Xray installation/validation failed. Installation stopped before SSH/OVPN WebSocket."
fi
if ! systemctl is-active --quiet xray; then
    systemctl start xray 2>/tmp/akbar-xray-start-error.log || {
        cat /tmp/akbar-xray-start-error.log 2>/dev/null || true
        journalctl -u xray -n 80 --no-pager 2>/dev/null || true
        die "Xray configuration is valid but the Xray service failed to start."
    }
fi
ok "Xray service is active."

# ============================================================
# SSH / OPENVPN / WEBSOCKET
# ============================================================

section "SSH / OPENVPN / WEBSOCKET"

download_script "$SSH_PATH/ssh-vpn.sh" /root/ssh-vpn.sh \
    || die "Unable to download corrected ssh-vpn.sh."

run_screened /root/ssh-vpn.sh \
    "Corrected SSH/OpenVPN/WebSocket installer" ssh-vpn /tmp/akbar-ssh.rc

# ============================================================
# OTHER SERVICES
# ============================================================
# These are deliberately installed after the corrected Xray/SSH
# stack. Their scripts must use their documented dedicated ports.
# None of the legacy websocket scripts are invoked here because
# the corrected ssh-vpn.sh owns 8880/2086 and Xray owns 80/443/8443.

section "SSTP"
if download_script "$SSTP_PATH/sstp.sh" /root/sstp.sh; then
    run_screened /root/sstp.sh SSTP sstp /tmp/akbar-sstp.rc
fi

section "SHADOWSOCKS-R"
if download_script "$SSR_PATH/ssr.sh" /root/ssr.sh; then
    run_screened /root/ssr.sh "Shadowsocks-R" ssr /tmp/akbar-ssr.rc
fi

section "SHADOWSOCKS"
if download_script "$SS_PATH/sodosok.sh" /root/sodosok.sh; then
    run_screened /root/sodosok.sh Shadowsocks ss /tmp/akbar-ss.rc
fi

section "WIREGUARD"
if download_script "$WG_PATH/wg.sh" /root/wg.sh; then
    run_screened /root/wg.sh WireGuard wg /tmp/akbar-wg.rc
fi

section "L2TP / IPSEC"
if download_script "$IPSEC_PATH/ipsec.sh" /root/ipsec.sh; then
    run_screened /root/ipsec.sh "L2TP / IPSEC" ipsec /tmp/akbar-ipsec.rc
fi

section "BACKUP / BRIDGE"
if download_script "$BACKUP_PATH/set-br.sh" /root/set-br.sh; then
    run_script /root/set-br.sh "Bridge / Backup Setup"
fi

# ============================================================
# OHP
# ============================================================

section "OHP"

if download_script "$OHP_PATH/ohp.sh" /root/ohp.sh; then
    run_script /root/ohp.sh "OHP Server"
fi

# ============================================================
# AUTOSSETT
# ============================================================

section "AUTO SETTING"

cat > /etc/systemd/system/autosett.service <<'EOF'
[Unit]
Description=Akbar VPN Auto Setting
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/set.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable autosett.service >/dev/null 2>&1 || true

if download_script "$SSH_PATH/set.sh" /etc/set.sh; then
    chmod 700 /etc/set.sh
    ok "Auto setting installed."
else
    warn "set.sh could not be downloaded."
fi

# ============================================================
# IMPORTANT: DO NOT INSTALL OLD edu.sh
# ============================================================
# The old setup.sh downloaded edu.sh here. That websocket installer
# can bind public 443/8880 and conflicts with the corrected stack.
# WebSocket SSH/OVPN is already installed by ssh-vpn.sh.

rm -f /root/edu.sh

# ============================================================
# SERVICE NORMALIZATION
# ============================================================

section "SERVICE NORMALIZATION"

systemctl daemon-reload

# Ensure corrected primary services are enabled.
systemctl enable xray nginx 2>/dev/null || true
systemctl enable ssh dropbear 2>/dev/null || true

# Do not restart random legacy services blindly. Their installers
# own their own configuration.

# ============================================================
# PORT COLLISION CHECK
# ============================================================

section "PORT CHECK"

echo "Primary listeners:"
ss -lntup 2>/dev/null | grep -E \
    ':(80|443|8443|8880|2086|2087|89|22|109|143|1194|2200|990|3128|7070|1701|1732|444)\b' \
    || true

echo
echo "Expected primary layout:"
echo "  80    -> HAProxy/Xray HTTP+Reality entry + SSH/OVPN WS paths"
echo "  443   -> Xray Reality entry + SSH/OVPN WS paths"
echo "  8443  -> Xray Reality entry + SSH/OVPN WS paths"
echo "  8880  -> SSH WebSocket backend"
echo "  2086  -> OpenVPN WebSocket backend"
echo "  2087  -> Trojan-Go"
echo

# ============================================================
# XRAY VALIDATION
# ============================================================

section "XRAY VALIDATION"

if command -v xray >/dev/null 2>&1 && [ -f /etc/xray/config.json ]; then
    if xray run -test -config /etc/xray/config.json; then
        ok "Xray configuration test passed."
    else
        warn "Xray configuration test failed."
    fi
fi

# ============================================================
# SYSTEMD STATUS
# ============================================================

section "PRIMARY SERVICES"

for svc in xray nginx ssh dropbear; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "[ACTIVE] $svc"
    else
        echo "[NOT ACTIVE] $svc"
    fi
done

# ============================================================
# VERSION / SUMMARY
# ============================================================

mkdir -p /home
echo "1.3" > /home/ver

END_TIME="$(date '+%Y-%m-%d %H:%M:%S')"

section "INSTALLATION COMPLETE"

echo "Start Time : $START_TIME"
echo "End Time   : $END_TIME"
echo "Public IP  : ${MYIP:-UNKNOWN}"
echo "Domain     : $DOMAIN"
echo
echo "Primary protocol stack:"
echo "  Xray VLESS Reality     : 443 / 8443"
echo "  HTTP/Web entry         : 80"
echo "  VMess WS               : Xray backend"
echo "  VLESS WS               : Xray backend"
echo "  Trojan WS              : Xray backend"
echo "  VLESS gRPC             : Xray backend"
echo "  Trojan gRPC            : Xray backend"
echo "  VLESS XHTTP            : Xray backend"
echo "  SSH WebSocket          : /ssh on 80/443/8443 (backend 8880)"
echo "  OpenVPN WebSocket      : /ovpn-ws on 80/443/8443 (backend 2086)"
echo "  Trojan-Go              : 2087"
echo
echo "Legacy/other VPN services are kept on their dedicated ports."
echo
echo "Log       : $LOG_FILE"
echo "Errors    : $ERROR_LOG"
echo
echo "============================================================"
echo "                 MAHBOUB VPN READY"
echo "============================================================"

# No automatic reboot here.
# A reboot is intentionally left to the administrator so that
# port/service problems can be inspected before restarting.
exit 0
