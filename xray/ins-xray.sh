#!/bin/bash

# ============================================================
# AKBAR VPN - XRAY INSTALLER
# Modern Xray Installer
# Ubuntu / Debian
#
# PUBLIC:
#   80   -> Nginx HTTP
#   8443 -> Nginx HTTPS
#
# INTERNAL:
#   10001 VMess WS TLS
#   10002 VLESS WS TLS
#   10003 Trojan WS TLS
#   10004 VMess WS HTTP
#   10005 VLESS WS HTTP
#   10006 VLESS gRPC TLS
#   10007 Trojan gRPC TLS
#   10008 VLESS XHTTP TLS
#   10009 VLESS XHTTP HTTP
#
# REALITY:
#   10443 VLESS Reality
#
# ============================================================

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

LOG_FILE="/root/xray-install.log"
INFO_FILE="/root/xray-install-info.txt"

mkdir -p /var/log

exec > >(tee -a "$LOG_FILE") 2>&1

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# ============================================================
# UI
# ============================================================

banner() {
    clear
    echo -e "${CYAN}"
    echo "============================================================"
    echo "                 AKBAR VPN XRAY INSTALLER"
    echo "============================================================"
    echo -e "${NC}"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

die() {
    error "$1"
    echo
    echo "Installation stopped."
    echo "Full log:"
    echo "$LOG_FILE"
    exit 1
}

run() {
    "$@"
    local rc=$?

    if [ $rc -ne 0 ]; then
        error "Command failed: $*"
        return $rc
    fi

    return 0
}

# ============================================================
# ROOT
# ============================================================

if [ "${EUID}" -ne 0 ]; then
    die "Run this installer as root."
fi

banner

# ============================================================
# VIRTUALIZATION
# ============================================================

if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT=$(systemd-detect-virt 2>/dev/null || true)

    if [ "$VIRT" = "openvz" ]; then
        die "OpenVZ is not supported."
    fi
fi

# ============================================================
# OS DETECTION
# ============================================================

info "Detecting operating system..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    die "Cannot detect operating system."
fi

OS_ID="${ID}"
OS_VERSION="${VERSION_ID}"

echo "OS       : $OS_ID"
echo "Version  : $OS_VERSION"
echo

case "$OS_ID" in
    ubuntu|debian)
        ok "Supported OS detected."
        ;;
    *)
        die "This installer supports Ubuntu and Debian."
        ;;
esac

# ============================================================
# PACKAGE MANAGER LOCK FIX
# ============================================================

wait_for_apt() {

    info "Checking package manager..."

    local timeout=600
    local elapsed=0

    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
       || fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
       || fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do

        if [ $elapsed -ge $timeout ]; then
            error "Package manager is still locked after ${timeout}s."
            return 1
        fi

        echo -ne "\r${YELLOW}Waiting for apt/dpkg lock... ${elapsed}s${NC}"
        sleep 3
        elapsed=$((elapsed + 3))
    done

    echo
    ok "Package manager ready."
}

wait_for_apt || die "Could not obtain apt/dpkg lock."

# ============================================================
# REPAIR DPKG
# ============================================================

info "Repairing package database..."

dpkg --configure -a || true
apt-get -f install -y || true

wait_for_apt || die "Package manager lock unavailable."

# ============================================================
# BASIC PACKAGES
# ============================================================

info "Installing dependencies..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y || die "apt update failed."

PACKAGES="
curl
wget
ca-certificates
unzip
jq
openssl
uuid-runtime
socat
lsof
net-tools
iproute2
iptables
iptables-persistent
cron
bash-completion
gnupg
"

apt-get install -y $PACKAGES || die "Failed to install basic dependencies."

# ============================================================
# TIME
# ============================================================

info "Configuring system time..."

apt-get install -y chrony || warn "Chrony installation failed."

systemctl enable chrony 2>/dev/null || true
systemctl restart chrony 2>/dev/null || true

timedatectl set-ntp true 2>/dev/null || true

# Preserve your existing timezone
timedatectl set-timezone Asia/Jakarta 2>/dev/null || true

# ntpdate is obsolete on newer Ubuntu/Debian.
# Do NOT install ntpdate.
ok "Time synchronization configured."

# ============================================================
# DOMAIN
# ============================================================

if [ ! -f /etc/xray/domain ]; then

    if [ -f /root/domain ]; then
        mkdir -p /etc/xray
        cp /root/domain /etc/xray/domain
    fi
fi

if [ ! -f /etc/xray/domain ]; then
    echo
    read -rp "Enter your domain: " DOMAIN
    echo "$DOMAIN" > /etc/xray/domain
else
    DOMAIN=$(cat /etc/xray/domain | head -n1 | tr -d '[:space:]')
fi

[ -n "$DOMAIN" ] || die "Domain is empty."

ok "Domain: $DOMAIN"

# ============================================================
# PUBLIC IP
# ============================================================

info "Detecting public IP..."

MYIP=$(curl -4 -fsSL --max-time 10 https://api.ipify.org 2>/dev/null || true)

if [ -z "$MYIP" ]; then
    MYIP=$(curl -4 -fsSL --max-time 10 https://ifconfig.me 2>/dev/null || true)
fi

echo "Public IP : $MYIP"

# ============================================================
# DIRECTORIES
# ============================================================

mkdir -p /etc/xray
mkdir -p /var/log/xray
mkdir -p /var/lib/akbarstorevpn

chmod 755 /etc/xray

# ============================================================
# DOWNLOAD LATEST XRAY
# ============================================================

info "Downloading latest Xray release..."

XRAY_API="https://api.github.com/repos/XTLS/Xray-core/releases/latest"

XRAY_TAG=$(curl -fsSL "$XRAY_API" \
    | jq -r '.tag_name' 2>/dev/null || true)

if [ -z "$XRAY_TAG" ] || [ "$XRAY_TAG" = "null" ]; then
    die "Unable to determine latest Xray version."
fi

XRAY_VERSION="${XRAY_TAG#v}"

echo "Xray version : $XRAY_VERSION"

ARCH=$(uname -m)

case "$ARCH" in
    x86_64|amd64)
        XRAY_ARCH="64"
        ;;
    aarch64|arm64)
        XRAY_ARCH="arm64-v8a"
        ;;
    armv7l)
        XRAY_ARCH="arm32-v7a"
        ;;
    *)
        die "Unsupported architecture: $ARCH"
        ;;
esac

XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_TAG}/Xray-linux-${XRAY_ARCH}.zip"

TMP_DIR=$(mktemp -d)

curl -fL "$XRAY_URL" -o "$TMP_DIR/xray.zip" \
    || die "Failed to download Xray."

unzip -oq "$TMP_DIR/xray.zip" -d "$TMP_DIR/xray" \
    || die "Failed to extract Xray."

if [ ! -f "$TMP_DIR/xray/xray" ]; then
    die "Xray binary was not found after extraction."
fi

install -m 0755 "$TMP_DIR/xray/xray" /usr/local/bin/xray

rm -rf "$TMP_DIR"

ok "Xray installed."

/usr/local/bin/xray version || die "Xray binary does not work."

# ============================================================
# UUIDS
# ============================================================

info "Generating UUIDs..."

UUID_VMESS_TLS=$(uuidgen)
UUID_VLESS_TLS=$(uuidgen)
UUID_TROJAN=$(uuidgen)
UUID_VMESS_HTTP=$(uuidgen)
UUID_VLESS_HTTP=$(uuidgen)
UUID_VLESS_GRPC=$(uuidgen)
UUID_TROJAN_GRPC=$(uuidgen)
UUID_VLESS_XHTTP=$(uuidgen)
UUID_VLESS_XHTTP_HTTP=$(uuidgen)
UUID_REALITY=$(uuidgen)

# ============================================================
# REALITY KEYS
# ============================================================

info "Generating Reality key pair..."

REALITY_KEYS=$(/usr/local/bin/xray x25519 2>/dev/null || true)

PRIVATE_KEY=$(echo "$REALITY_KEYS" \
    | awk -F': ' '/Private key/ {print $2; exit}')

PUBLIC_KEY=$(echo "$REALITY_KEYS" \
    | awk -F': ' '/Password/ {print $2; exit}')

if [ -z "$PRIVATE_KEY" ]; then
    PRIVATE_KEY=$(echo "$REALITY_KEYS" \
        | awk -F': ' '/PrivateKey/ {print $2; exit}')
fi

if [ -z "$PUBLIC_KEY" ]; then
    PUBLIC_KEY=$(echo "$REALITY_KEYS" \
        | awk -F': ' '/PublicKey/ {print $2; exit}')
fi

if [ -z "$PRIVATE_KEY" ]; then
    warn "Could not automatically parse Reality key output."
    warn "Reality configuration will be generated after manual key detection."
fi

# ============================================================
# REALITY DESTINATION
# ============================================================

REALITY_DEST="www.cloudflare.com:443"
REALITY_SERVER_NAME="www.cloudflare.com"

# ============================================================
# XRAY CONFIG
# ============================================================

info "Creating Xray configuration..."

cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },

  "inbounds": [

    {
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID_VMESS_TLS",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vmess/"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID_VLESS_TLS"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vless/"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$UUID_TROJAN"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/trojan/"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID_VMESS_HTTP",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vmess/"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10005,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID_VLESS_HTTP"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vless/"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10006,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID_VLESS_GRPC"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "vless-grpc"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10007,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$UUID_TROJAN_GRPC"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "trojan-grpc"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10008,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID_VLESS_XHTTP"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "path": "/xhttp/"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10009,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID_VLESS_XHTTP_HTTP"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "path": "/xhttp/"
        }
      }
    },

EOF

# ============================================================
# REALITY
# ============================================================

if [ -n "$PRIVATE_KEY" ]; then

cat >> /etc/xray/config.json <<EOF

    {
      "listen": "0.0.0.0",
      "port": 10443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID_REALITY",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$REALITY_DEST",
          "xver": 0,
          "serverNames": [
            "$REALITY_SERVER_NAME"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "0123456789abcdef"
          ]
        }
      }
    },

EOF

fi

# ============================================================
# CLOSE CONFIG
# ============================================================

cat >> /etc/xray/config.json <<EOF

    {
      "listen": "127.0.0.1",
      "port": 10010,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": 89,
        "network": "tcp"
      }
    }

  ],

  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],

  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  },

  "stats": {},

  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  }
}
EOF

chmod 600 /etc/xray/config.json

# ============================================================
# CONFIG TEST
# ============================================================

info "Testing Xray configuration..."

if /usr/local/bin/xray run -test -config /etc/xray/config.json; then
    ok "Xray configuration is valid."
else
    die "Xray configuration test failed."
fi

# ============================================================
# NGINX
# ============================================================

info "Installing Nginx..."

wait_for_apt || die "Package manager unavailable."

apt-get install -y nginx || die "Nginx installation failed."

systemctl stop nginx 2>/dev/null || true

# ============================================================
# NGINX CONFIG
# ============================================================

info "Creating Nginx reverse proxy..."

mkdir -p /var/www/html

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>$DOMAIN</title>
</head>
<body>
<h1>Welcome</h1>
</body>
</html>
EOF

rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-available/xray.conf <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN;

    root /var/www/html;
    index index.html;

    location /vmess/ {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /vless/ {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /trojan/ {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /grpc/ {
        grpc_pass grpc://127.0.0.1:10006;
    }

    location /trojan-grpc/ {
        grpc_pass grpc://127.0.0.1:10007;
    }

    location /xhttp/ {
        proxy_pass http://127.0.0.1:10008;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf /etc/nginx/sites-available/xray.conf /etc/nginx/sites-enabled/xray.conf

# ============================================================
# CERTIFICATE
# ============================================================

info "Checking TLS certificate..."

mkdir -p /etc/xray

if [ -f /etc/xray/xray.crt ] && [ -f /etc/xray/xray.key ]; then
    ok "Existing Xray certificate found."
else

    info "Installing ACME..."

    curl -fsSL https://get.acme.sh | sh -s email=admin@"$DOMAIN" \
        || warn "ACME installation failed."

    export PATH="/root/.acme.sh:$PATH"

    if command -v acme.sh >/dev/null 2>&1; then

        systemctl stop nginx 2>/dev/null || true

        acme.sh --issue \
            --standalone \
            -d "$DOMAIN" \
            --force \
            || warn "Certificate issuance failed."

        if [ -f "/root/.acme.sh/$DOMAIN/fullchain.cer" ]; then

            acme.sh --install-cert \
                -d "$DOMAIN" \
                --fullchain-file /etc/xray/xray.crt \
                --key-file /etc/xray/xray.key \
                --reloadcmd "systemctl restart nginx xray" \
                || warn "Certificate installation failed."

        fi
    fi
fi

if [ ! -f /etc/xray/xray.crt ] || [ ! -f /etc/xray/xray.key ]; then
    warn "TLS certificate is not available."
    warn "HTTPS services will not work until the certificate is installed."
fi

# ============================================================
# NGINX HTTPS
# ============================================================

if [ -f /etc/xray/xray.crt ] && [ -f /etc/xray/xray.key ]; then

cat >> /etc/nginx/sites-available/xray.conf <<EOF

server {
    listen 8443 ssl http2;
    listen [::]:8443 ssl http2;

    server_name $DOMAIN;

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;

    ssl_protocols TLSv1.2 TLSv1.3;

    root /var/www/html;
    index index.html;

    location /vmess/ {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /vless/ {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /trojan/ {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /grpc/ {
        grpc_pass grpc://127.0.0.1:10006;
    }

    location /trojan-grpc/ {
        grpc_pass grpc://127.0.0.1:10007;
    }

    location /xhttp/ {
        proxy_pass http://127.0.0.1:10008;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

fi

# ============================================================
# NGINX TEST
# ============================================================

nginx -t || die "Nginx configuration test failed."

systemctl enable nginx
systemctl restart nginx || warn "Nginx failed to start."

# ============================================================
# XRAY SERVICE
# ============================================================

cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service By Akbar Maulana
Documentation=https://t.me/Akbar218
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=simple
User=root

ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json

Restart=on-failure
RestartSec=3

LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray

systemctl restart xray || die "Xray service failed to start."

sleep 2

if systemctl is-active --quiet xray; then
    ok "Xray service is running."
else
    journalctl -u xray --no-pager -n 50
    die "Xray service failed."
fi

# ============================================================
# FIREWALL
# ============================================================

info "Configuring firewall..."

iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 8443 -j ACCEPT
iptables -I INPUT -p tcp --dport 10443 -j ACCEPT

iptables-save > /etc/iptables.up.rules 2>/dev/null || true

if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save || true
    netfilter-persistent reload || true
fi

# ============================================================
# INFORMATION FILE
# ============================================================

cat > "$INFO_FILE" <<EOF
============================================================
XRAY INSTALLATION
============================================================
Date:
$START_TIME

Domain:
$DOMAIN

Public IP:
$MYIP

Xray Version:
$XRAY_VERSION

------------------------------------------------------------
VMESS TLS
------------------------------------------------------------
Public Port : 8443
Path        : /vmess/
UUID        : $UUID_VMESS_TLS

------------------------------------------------------------
VLESS TLS
------------------------------------------------------------
Public Port : 8443
Path        : /vless/
UUID        : $UUID_VLESS_TLS

------------------------------------------------------------
TROJAN WS TLS
------------------------------------------------------------
Public Port : 8443
Path        : /trojan/
Password    : $UUID_TROJAN

------------------------------------------------------------
VLESS gRPC TLS
------------------------------------------------------------
Public Port : 8443
ServiceName : vless-grpc
UUID        : $UUID_VLESS_GRPC

------------------------------------------------------------
TROJAN gRPC TLS
------------------------------------------------------------
Public Port : 8443
ServiceName : trojan-grpc
Password    : $UUID_TROJAN_GRPC

------------------------------------------------------------
VLESS XHTTP
------------------------------------------------------------
Public Port : 8443
Path        : /xhttp/
UUID        : $UUID_VLESS_XHTTP

------------------------------------------------------------
VMESS HTTP
------------------------------------------------------------
Public Port : 80
Path        : /vmess/
UUID        : $UUID_VMESS_HTTP

------------------------------------------------------------
VLESS HTTP
------------------------------------------------------------
Public Port : 80
Path        : /vless/
UUID        : $UUID_VLESS_HTTP

------------------------------------------------------------
VLESS XHTTP HTTP
------------------------------------------------------------
Public Port : 80
Path        : /xhttp/
UUID        : $UUID_VLESS_XHTTP_HTTP

------------------------------------------------------------
VLESS REALITY
------------------------------------------------------------
Public Port : 10443
UUID        : $UUID_REALITY
ServerName  : $REALITY_SERVER_NAME
Destination : $REALITY_DEST
PrivateKey  : $PRIVATE_KEY
PublicKey   : $PUBLIC_KEY
ShortID     : 0123456789abcdef
Flow        : xtls-rprx-vision

------------------------------------------------------------
CERTIFICATE
------------------------------------------------------------
Certificate : /etc/xray/xray.crt
Private Key : /etc/xray/xray.key

------------------------------------------------------------
SERVICES
------------------------------------------------------------
Xray        : xray.service
Nginx       : nginx.service

------------------------------------------------------------
INTERNAL PORTS
------------------------------------------------------------
VMess WS TLS       : 10001
VLESS WS TLS       : 10002
Trojan WS TLS      : 10003
VMess WS HTTP      : 10004
VLESS WS HTTP      : 10005
VLESS gRPC         : 10006
Trojan gRPC        : 10007
VLESS XHTTP TLS    : 10008
VLESS XHTTP HTTP   : 10009
Reality            : 10443

------------------------------------------------------------
LOGS
------------------------------------------------------------
Installer Log : $LOG_FILE
Xray Access   : /var/log/xray/access.log
Xray Error    : /var/log/xray/error.log
============================================================
EOF

# ============================================================
# COMPATIBILITY FILES
# ============================================================

mkdir -p /var/lib/akbarstorevpn

cat > /var/lib/akbarstorevpn/ipvps.conf <<EOF
IP=$MYIP
EOF

# ============================================================
# DISPLAY
# ============================================================

echo
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}             XRAY INSTALLATION COMPLETED${NC}"
echo -e "${GREEN}============================================================${NC}"
echo
echo -e "${WHITE}Domain:${NC} $DOMAIN"
echo
echo -e "${CYAN}TLS:${NC}     8443"
echo -e "${CYAN}HTTP:${NC}    80"
echo -e "${CYAN}Reality:${NC} 10443"
echo
echo "VMess TLS       : 8443 /vmess/"
echo "VLESS TLS       : 8443 /vless/"
echo "Trojan TLS      : 8443 /trojan/"
echo "VLESS gRPC      : 8443 /grpc/"
echo "Trojan gRPC     : 8443 /trojan-grpc/"
echo "VLESS XHTTP     : 8443 /xhttp/"
echo
echo "VMess HTTP      : 80 /vmess/"
echo "VLESS HTTP      : 80 /vless/"
echo "VLESS XHTTP     : 80 /xhttp/"
echo
echo "VLESS Reality   : 10443"
echo
echo -e "${YELLOW}Installation log:${NC}"
echo "$LOG_FILE"
echo
echo -e "${YELLOW}Connection information:${NC}"
echo "$INFO_FILE"
echo
echo -e "${GREEN}============================================================${NC}"
echo

# ============================================================
# FINAL STATUS
# ============================================================

systemctl --no-pager --full status xray | tail -n 15 || true
systemctl --no-pager --full status nginx | tail -n 15 || true

echo
echo -e "${GREEN}Done.${NC}"
