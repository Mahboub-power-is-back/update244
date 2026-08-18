#!/bin/bash

# ============================================================
# Akbar Xray Installer
# Debian / Ubuntu
# VMess + VLESS + Trojan WS/TLS
# Trojan-Go WS
# ============================================================

set -Eeuo pipefail

# ============================================================
# Colors
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
# Error Handler
# ============================================================

trap 'echo -e "${RED}[ERROR]${NC} Line $LINENO: $BASH_COMMAND"; exit 1' ERR

# ============================================================
# Root Check
# ============================================================

if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}You need to run this script as root.${NC}"
    exit 1
fi

# ============================================================
# OS Detection
# ============================================================

if [ ! -f /etc/os-release ]; then
    echo -e "${RED}Cannot detect operating system.${NC}"
    exit 1
fi

. /etc/os-release

case "${ID}" in
    debian|ubuntu)
        ;;
    *)
        echo -e "${RED}Supported OS: Debian / Ubuntu${NC}"
        echo -e "${ORANGE}Detected: ${ID}${NC}"
        exit 1
        ;;
esac

echo -e "${CYAN}OS:${NC} ${PRETTY_NAME}"

# ============================================================
# Virtualization Check
# ============================================================

VIRT="$(systemd-detect-virt 2>/dev/null || true)"

if [ "$VIRT" = "openvz" ]; then
    echo -e "${RED}OpenVZ is not supported.${NC}"
    exit 1
fi

# ============================================================
# Variables
# ============================================================

MYIP="$(curl -4 -fsS --max-time 10 https://ipinfo.io/ip 2>/dev/null || true)"

if [ -z "$MYIP" ]; then
    MYIP="$(wget -qO- --timeout=10 https://ipinfo.io/ip 2>/dev/null || true)"
fi

if [ ! -f /etc/xray/domain ]; then
    echo -e "${RED}/etc/xray/domain not found.${NC}"
    echo -e "${ORANGE}Make sure your domain installation runs before ins-xray.sh.${NC}"
    exit 1
fi

domain="$(tr -d '[:space:]' < /etc/xray/domain)"

if [ -z "$domain" ]; then
    echo -e "${RED}Domain is empty.${NC}"
    exit 1
fi

echo -e "${GREEN}Domain:${NC} $domain"
echo -e "${GREEN}IP:${NC} ${MYIP:-unknown}"

# ============================================================
# Package Helpers
# ============================================================

export DEBIAN_FRONTEND=noninteractive

apt_fix() {
    dpkg --configure -a >/dev/null 2>&1 || true
    apt-get -f install -y >/dev/null 2>&1 || true
}

apt_install() {
    apt_fix
    apt-get update -y
    apt-get install -y "$@"
}

# ============================================================
# Base Dependencies
# ============================================================

echo -e "${CYAN}[1/10] Installing dependencies...${NC}"

apt_install \
    ca-certificates \
    curl \
    wget \
    unzip \
    zip \
    xz-utils \
    socat \
    cron \
    bash-completion \
    dnsutils \
    lsb-release \
    gnupg \
    gnupg2 \
    gnupg1 \
    apt-transport-https \
    iptables \
    iptables-persistent \
    netfilter-persistent \
    openssl \
    lsof \
    nginx \
    jq \
    procps \
    systemd

# ============================================================
# Time
# ============================================================

echo -e "${CYAN}[2/10] Configuring time synchronization...${NC}"

if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone Asia/Jakarta || true
fi

apt_install chrony

systemctl enable chrony >/dev/null 2>&1 || true
systemctl restart chrony >/dev/null 2>&1 || true

if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-ntp true || true
fi

chronyc tracking >/dev/null 2>&1 || true

date

# ============================================================
# Directories
# ============================================================

echo -e "${CYAN}[3/10] Preparing directories...${NC}"

mkdir -p /usr/bin/xray
mkdir -p /etc/xray
mkdir -p /var/log/xray
mkdir -p /etc/trojan-go
mkdir -p /var/log/trojan-go

touch /var/log/xray/access.log
touch /var/log/xray/error.log
touch /var/log/trojan-go/trojan-go.log

chmod 755 /etc/xray
chmod 755 /var/log/xray

# ============================================================
# Download Helper
# ============================================================

download_file() {
    local url="$1"
    local output="$2"

    echo -e "${BLUE}Downloading:${NC} $url"

    for attempt in 1 2 3 4 5; do
        if curl -fL --retry 3 --connect-timeout 15 --max-time 300 \
            "$url" -o "$output"; then
            return 0
        fi

        echo -e "${ORANGE}Download failed. Retry ${attempt}/5...${NC}"
        sleep 2
    done

    echo -e "${RED}Download failed:${NC} $url"
    return 1
}

# ============================================================
# Latest Xray Version
# ============================================================

echo -e "${CYAN}[4/10] Installing latest Xray Core...${NC}"

latest_version="$(
    curl -fsSL \
    --retry 5 \
    --connect-timeout 15 \
    https://api.github.com/repos/XTLS/Xray-core/releases/latest |
    jq -r '.tag_name' |
    sed 's/^v//'
)"

if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
    echo -e "${RED}Unable to determine Xray version.${NC}"
    exit 1
fi

echo -e "${GREEN}Xray version:${NC} v${latest_version}"

xraycore_link="https://github.com/XTLS/Xray-core/releases/download/v${latest_version}/Xray-linux-64.zip"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

download_file "$xraycore_link" "$tmpdir/xray.zip"

unzip -qo "$tmpdir/xray.zip" -d "$tmpdir/xray"

if [ ! -f "$tmpdir/xray/xray" ]; then
    echo -e "${RED}Xray binary was not found after extraction.${NC}"
    exit 1
fi

install -m 0755 "$tmpdir/xray/xray" /usr/local/bin/xray

# Compatibility path
ln -sf /usr/local/bin/xray /usr/bin/xray

/usr/local/bin/xray version

# ============================================================
# Stop Existing Services
# ============================================================

echo -e "${CYAN}[5/10] Preparing ports and existing services...${NC}"

systemctl stop xray.service 2>/dev/null || true
systemctl stop trojan-go.service 2>/dev/null || true
systemctl stop nginx.service 2>/dev/null || true

# Stop services currently listening on 80/8443 if required
for port in 80 8443; do
    if command -v lsof >/dev/null 2>&1; then
        lsof -t -iTCP:"$port" -sTCP:LISTEN 2>/dev/null |
            xargs -r kill 2>/dev/null || true
    fi
done

# ============================================================
# ACME
# ============================================================

echo -e "${CYAN}[6/10] Installing / renewing certificate...${NC}"

cd /root

if [ ! -f /root/.acme.sh/acme.sh ]; then
    download_file \
        "https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh" \
        "/root/acme.sh"

    chmod +x /root/acme.sh

    bash /root/acme.sh --install \
        --home /root/.acme.sh \
        --accountemail senowahyu62@gmail.com

    rm -f /root/acme.sh
fi

/root/.acme.sh/acme.sh \
    --register-account \
    -m senowahyu62@gmail.com \
    >/dev/null 2>&1 || true

/root/.acme.sh/acme.sh \
    --issue \
    --standalone \
    -d "$domain" \
    --force

/root/.acme.sh/acme.sh \
    --install-cert \
    -d "$domain" \
    --fullchain-file /etc/xray/xray.crt \
    --key-file /etc/xray/xray.key \
    --reloadcmd "systemctl reload nginx >/dev/null 2>&1 || true"

if [ ! -s /etc/xray/xray.crt ] || [ ! -s /etc/xray/xray.key ]; then
    echo -e "${RED}Certificate installation failed.${NC}"
    exit 1
fi

chmod 644 /etc/xray/xray.crt
chmod 600 /etc/xray/xray.key

# ============================================================
# UUID
# ============================================================

uuid1="$(cat /proc/sys/kernel/random/uuid)"
uuid2="$(cat /proc/sys/kernel/random/uuid)"
uuid3="$(cat /proc/sys/kernel/random/uuid)"
uuid4="$(cat /proc/sys/kernel/random/uuid)"
uuid5="$(cat /proc/sys/kernel/random/uuid)"
uuid6="$(cat /proc/sys/kernel/random/uuid)"

path_crt="/etc/xray/xray.crt"
path_key="/etc/xray/xray.key"

# ============================================================
# Internal Xray Ports
#
# Public:
#   80   -> Nginx
#   8443 -> Nginx
#
# Internal:
#   VMess TLS       10001
#   VLESS TLS       10002
#   Trojan TLS      10003
#   VMess non-TLS   10004
#   VLESS non-TLS   10005
# ============================================================

VMESS_TLS_PORT=10001
VLESS_TLS_PORT=10002
TROJAN_TLS_PORT=10003

VMESS_HTTP_PORT=10004
VLESS_HTTP_PORT=10005

# ============================================================
# Xray Config
# ============================================================

echo -e "${CYAN}[7/10] Creating Xray configuration...${NC}"

cat > /etc/xray/config.json << END
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },

  "inbounds": [

    {
      "port": ${VMESS_TLS_PORT},
      "listen": "127.0.0.1",
      "protocol": "vmess",

      "settings": {
        "clients": [
          {
            "id": "${uuid1}",
            "alterId": 0
          }
        ]
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/vmess/",
          "headers": {
            "Host": ""
          }
        }
      }
    },

    {
      "port": ${VMESS_HTTP_PORT},
      "listen": "127.0.0.1",
      "protocol": "vmess",

      "settings": {
        "clients": [
          {
            "id": "${uuid2}",
            "alterId": 0
          }
        ]
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/vmess/",
          "headers": {
            "Host": ""
          }
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "port": ${VLESS_TLS_PORT},
      "listen": "127.0.0.1",
      "protocol": "vless",

      "settings": {
        "clients": [
          {
            "id": "${uuid3}"
          }
        ],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/vless/",
          "headers": {
            "Host": ""
          }
        }
      },

      "domain": "${domain}",

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "port": ${VLESS_HTTP_PORT},
      "listen": "127.0.0.1",
      "protocol": "vless",

      "settings": {
        "clients": [
          {
            "id": "${uuid4}"
          }
        ],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/vless/",
          "headers": {
            "Host": ""
          }
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "port": ${TROJAN_TLS_PORT},
      "listen": "127.0.0.1",
      "protocol": "trojan",

      "settings": {
        "clients": [
          {
            "password": "${uuid5}"
          }
        ]
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/trojan/",
          "headers": {
            "Host": "${domain}"
          }
        }
      },

      "domain": "${domain}",

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }

  ],

  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },

    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],

  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },

      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },

      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },

  "stats": {},

  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },

  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },

    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  }
}
END

# ============================================================
# Validate Xray
# ============================================================

echo -e "${CYAN}Validating Xray configuration...${NC}"

if ! /usr/local/bin/xray run \
    -test \
    -config /etc/xray/config.json; then

    echo -e "${RED}Xray configuration validation failed.${NC}"
    exit 1
fi

echo -e "${GREEN}Xray configuration OK.${NC}"

# ============================================================
# Xray Service
# ============================================================

cat > /etc/systemd/system/xray.service << END
[Unit]
Description=Xray Service By Akbar Maulana
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
Type=simple
User=root

CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json

Restart=on-failure
RestartSec=3
RestartPreventExitStatus=23

LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
END

# ============================================================
# Nginx WS Multiplexer
# ============================================================

echo -e "${CYAN}Creating WS multiplexer...${NC}"

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

cat > /etc/nginx/sites-available/xray-ws << END
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    listen [::]:80;

    server_name ${domain};

    location /vmess/ {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:${VMESS_HTTP_PORT};
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_read_timeout 86400;
    }

    location /vless/ {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:${VLESS_HTTP_PORT};
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_read_timeout 86400;
    }

    location / {
        return 404;
    }
}

server {
    listen 8443 ssl;
    listen [::]:8443 ssl;

    server_name ${domain};

    ssl_certificate ${path_crt};
    ssl_certificate_key ${path_key};

    ssl_protocols TLSv1.2 TLSv1.3;

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location /vmess/ {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:${VMESS_TLS_PORT};
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_read_timeout 86400;
    }

    location /vless/ {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:${VLESS_TLS_PORT};
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_read_timeout 86400;
    }

    location /trojan/ {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:${TROJAN_TLS_PORT};
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_read_timeout 86400;
    }

    location / {
        return 404;
    }
}
END

ln -sf /etc/nginx/sites-available/xray-ws \
    /etc/nginx/sites-enabled/xray-ws

nginx -t

# ============================================================
# Trojan-Go
# ============================================================

echo -e "${CYAN}[8/10] Installing Trojan-Go...${NC}"

latest_trojango_version="$(
    curl -fsSL \
    --retry 5 \
    --connect-timeout 15 \
    "https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest" |
    jq -r '.tag_name'
)"

if [ -z "$latest_trojango_version" ] ||
   [ "$latest_trojango_version" = "null" ]; then

    echo -e "${RED}Unable to determine Trojan-Go version.${NC}"
    exit 1
fi

trojango_link="https://github.com/p4gefau1t/trojan-go/releases/download/${latest_trojango_version}/trojan-go-linux-amd64.zip"

trojandir="$(mktemp -d)"

download_file "$trojango_link" "$trojandir/trojan-go.zip"

unzip -qo "$trojandir/trojan-go.zip" -d "$trojandir"

if [ ! -f "$trojandir/trojan-go" ]; then
    echo -e "${RED}Trojan-Go binary not found after extraction.${NC}"
    exit 1
fi

install -m 0755 \
    "$trojandir/trojan-go" \
    /usr/local/bin/trojan-go

ln -sf /usr/local/bin/trojan-go /usr/bin/trojan-go

rm -rf "$trojandir"

# ============================================================
# Trojan-Go Config
# ============================================================

cat > /etc/trojan-go/config.json << END
{
  "run_type": "server",

  "local_addr": "0.0.0.0",
  "local_port": 2087,

  "remote_addr": "127.0.0.1",
  "remote_port": 89,

  "log_level": 1,
  "log_file": "/var/log/trojan-go/trojan-go.log",

  "password": [
    "${uuid6}"
  ],

  "disable_http_check": true,
  "udp_timeout": 60,

  "ssl": {
    "verify": false,
    "verify_hostname": false,

    "cert": "${path_crt}",
    "key": "${path_key}",

    "key_password": "",

    "cipher": "",
    "curves": "",

    "prefer_server_cipher": false,

    "sni": "${domain}",

    "alpn": [
      "http/1.1"
    ],

    "session_ticket": true,
    "reuse_session": true,

    "plain_http_response": "",

    "fallback_addr": "127.0.0.1",
    "fallback_port": 0,

    "fingerprint": "firefox"
  },

  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "prefer_ipv4": true
  },

  "mux": {
    "enabled": false,
    "concurrency": 8,
    "idle_timeout": 60
  },

  "websocket": {
    "enabled": true,
    "path": "/trojango",
    "host": "${domain}"
  },

  "api": {
    "enabled": false,
    "api_addr": "",
    "api_port": 0,

    "ssl": {
      "enabled": false,
      "key": "",
      "cert": "",
      "verify_client": false,
      "client_cert": []
    }
  }
}
END

# ============================================================
# Trojan-Go UUID
# ============================================================

cat > /etc/trojan-go/uuid.txt << END
${uuid6}
END

# ============================================================
# Trojan-Go Service
# ============================================================

cat > /etc/systemd/system/trojan-go.service << END
[Unit]
Description=Trojan-Go Service By Akbar Maulana
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
Type=simple
User=root

CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json

Restart=on-failure
RestartSec=3
RestartPreventExitStatus=23

LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
END

# ============================================================
# Firewall
# ============================================================

echo -e "${CYAN}[9/10] Configuring firewall...${NC}"

iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null ||
iptables -I INPUT -p tcp --dport 80 -j ACCEPT

iptables -C INPUT -p tcp --dport 8443 -j ACCEPT 2>/dev/null ||
iptables -I INPUT -p tcp --dport 8443 -j ACCEPT

iptables -C INPUT -p tcp --dport 2087 -j ACCEPT 2>/dev/null ||
iptables -I INPUT -p tcp --dport 2087 -j ACCEPT

iptables -C INPUT -p udp --dport 2087 -j ACCEPT 2>/dev/null ||
iptables -I INPUT -p udp --dport 2087 -j ACCEPT

# Keep your existing firewall port
iptables -C INPUT -p tcp --dport 2083 -j ACCEPT 2>/dev/null ||
iptables -I INPUT -p tcp --dport 2083 -j ACCEPT

iptables -C INPUT -p udp --dport 2083 -j ACCEPT 2>/dev/null ||
iptables -I INPUT -p udp --dport 2083 -j ACCEPT

iptables-save > /etc/iptables.up.rules

netfilter-persistent save >/dev/null 2>&1 || true
netfilter-persistent reload >/dev/null 2>&1 || true

# ============================================================
# Start Services
# ============================================================

echo -e "${CYAN}[10/10] Starting services...${NC}"

systemctl daemon-reload

systemctl enable xray.service >/dev/null
systemctl enable trojan-go.service >/dev/null
systemctl enable nginx.service >/dev/null

systemctl restart xray.service
sleep 2

systemctl restart nginx.service
sleep 2

systemctl restart trojan-go.service
sleep 2

# ============================================================
# Service Verification
# ============================================================

echo
echo -e "${CYAN}Checking services...${NC}"

if systemctl is-active --quiet xray.service; then
    echo -e "${GREEN}[OK] Xray${NC}"
else
    echo -e "${RED}[FAIL] Xray${NC}"
    journalctl -u xray.service --no-pager -n 30
    exit 1
fi

if systemctl is-active --quiet nginx.service; then
    echo -e "${GREEN}[OK] Nginx${NC}"
else
    echo -e "${RED}[FAIL] Nginx${NC}"
    nginx -t || true
    journalctl -u nginx.service --no-pager -n 30
    exit 1
fi

if systemctl is-active --quiet trojan-go.service; then
    echo -e "${GREEN}[OK] Trojan-Go${NC}"
else
    echo -e "${RED}[FAIL] Trojan-Go${NC}"
    journalctl -u trojan-go.service --no-pager -n 30
    exit 1
fi

# ============================================================
# Domain Copy
# ============================================================

if [ -f /root/domain ]; then
    cp -f /root/domain /etc/xray/domain
fi

# ============================================================
# Save Information
# ============================================================

cat > /etc/xray/uuid.txt << END
VMESS_TLS=${uuid1}
VMESS_NONE_TLS=${uuid2}
VLESS_TLS=${uuid3}
VLESS_NONE_TLS=${uuid4}
TROJAN=${uuid5}
TROJAN_GO=${uuid6}
END

chmod 600 /etc/xray/uuid.txt

# ============================================================
# Installation Log
# ============================================================

cat > /root/xray-install-info.txt << END
============================================================
XRAY INSTALLATION
============================================================

Domain:
${domain}

Public IP:
${MYIP}

------------------------------------------------------------
VMESS TLS
------------------------------------------------------------
Port : 8443
Path : /vmess/
UUID : ${uuid1}

------------------------------------------------------------
VMESS NONE TLS
------------------------------------------------------------
Port : 80
Path : /vmess/
UUID : ${uuid2}

------------------------------------------------------------
VLESS TLS
------------------------------------------------------------
Port : 8443
Path : /vless/
UUID : ${uuid3}

------------------------------------------------------------
VLESS NONE TLS
------------------------------------------------------------
Port : 80
Path : /vless/
UUID : ${uuid4}

------------------------------------------------------------
TROJAN WS TLS
------------------------------------------------------------
Port     : 8443
Path     : /trojan/
Password : ${uuid5}

------------------------------------------------------------
TROJAN-GO WS
------------------------------------------------------------
Port     : 2087
Path     : /trojango
Password : ${uuid6}

------------------------------------------------------------
CERTIFICATE
------------------------------------------------------------
Certificate : ${path_crt}
Private Key : ${path_key}

------------------------------------------------------------
SERVICES
------------------------------------------------------------
Xray      : xray.service
Nginx     : nginx.service
Trojan-Go : trojan-go.service

------------------------------------------------------------
INTERNAL PORTS
------------------------------------------------------------
VMess TLS       : ${VMESS_TLS_PORT}
VLESS TLS       : ${VLESS_TLS_PORT}
Trojan TLS      : ${TROJAN_TLS_PORT}
VMess None TLS  : ${VMESS_HTTP_PORT}
VLESS None TLS  : ${VLESS_HTTP_PORT}

============================================================
END

# ============================================================
# Final Output
# ============================================================

clear

echo -e "${GREEN}"
echo "============================================================"
echo "              XRAY INSTALLATION COMPLETED"
echo "============================================================"
echo -e "${NC}"

echo -e "${CYAN}Domain:${NC} ${domain}"
echo -e "${CYAN}IP:${NC}     ${MYIP:-unknown}"
echo

echo -e "${GREEN}VMess TLS${NC}"
echo "  Port : 8443"
echo "  Path : /vmess/"
echo "  UUID : ${uuid1}"
echo

echo -e "${GREEN}VMess None TLS${NC}"
echo "  Port : 80"
echo "  Path : /vmess/"
echo "  UUID : ${uuid2}"
echo

echo -e "${GREEN}VLESS TLS${NC}"
echo "  Port : 8443"
echo "  Path : /vless/"
echo "  UUID : ${uuid3}"
echo

echo -e "${GREEN}VLESS None TLS${NC}"
echo "  Port : 80"
echo "  Path : /vless/"
echo "  UUID : ${uuid4}"
echo

echo -e "${GREEN}Trojan WS TLS${NC}"
echo "  Port     : 8443"
echo "  Path     : /trojan/"
echo "  Password : ${uuid5}"
echo

echo -e "${GREEN}Trojan-Go WS${NC}"
echo "  Port     : 2087"
echo "  Path     : /trojango"
echo "  Password : ${uuid6}"
echo

echo -e "${GREEN}Services:${NC}"
echo "  Xray      : $(systemctl is-active xray.service)"
echo "  Nginx     : $(systemctl is-active nginx.service)"
echo "  Trojan-Go : $(systemctl is-active trojan-go.service)"
echo

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}Installation completed successfully.${NC}"
echo -e "${GREEN}============================================================${NC}"
echo

echo "Information saved to:"
echo "/root/xray-install-info.txt"
echo "/etc/xray/uuid.txt"
echo

# ============================================================
# Optional compatibility file
# ============================================================

if [ -f /root/domain ]; then
    cp -f /root/domain /etc/xray/domain
fi

exit 0
