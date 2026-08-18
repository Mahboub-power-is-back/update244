#!/bin/bash
# ============================================================
# AKBAR VPN - XRAY INSTALLER (CORRECTED / MULTI-PROTOCOL)
# Ubuntu / Debian
#
# Public entry points:
#   80   HAProxy TCP mux: HTTP -> Nginx -> SSH/OVPN WS, TLS -> Xray Reality
#   443  Xray Reality + WS fallbacks (SSH/OVPN)
#   8443 Xray Reality + WS fallbacks (SSH/OVPN)
#
# Xray internal services:
#   10001 VMess WS
#   10002 VLESS WS
#   10003 Trojan WS
#   10004 VMess WS (HTTP profile)
#   10005 VLESS WS (HTTP profile)
#   10006 VLESS gRPC
#   10007 Trojan gRPC
#   10008 VLESS XHTTP
#   10009 VLESS XHTTP
#
# Trojan-Go:
#   2087 TCP/TLS/WS (direct service; deliberately not bound to
#   80/443/8443 so it cannot collide with the multiplexers).
#
# IMPORTANT:
# Independent daemons cannot all bind the same IP:port. This
# installer uses Xray fallbacks + HAProxy + Nginx to multiplex
# protocols instead of creating conflicting listeners.
# ============================================================

set -Eeuo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

LOG_FILE=/root/xray-install.log
exec > >(tee -a "$LOG_FILE") 2>&1

die(){ echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }

[ "$EUID" -eq 0 ] || die "Run as root."

. /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) die "Only Ubuntu and Debian are supported." ;;
esac

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) XRAY_ARCH=64; TG_ARCH=amd64 ;;
  arm64) XRAY_ARCH=arm64-v8a; TG_ARCH=arm64 ;;
  armhf) XRAY_ARCH=arm32-v7a; TG_ARCH=armv7 ;;
  *) die "Unsupported architecture: $ARCH" ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl wget unzip jq openssl uuid-runtime \
  nginx haproxy iptables iptables-persistent socat lsof chrony

systemctl enable --now chrony || true

mkdir -p /etc/xray /var/log/xray /var/www/html /etc/trojan-go /var/log/trojan-go

# ------------------------------------------------------------
# Domain
# ------------------------------------------------------------
if [ -f /etc/xray/domain ]; then
  DOMAIN="$(head -n1 /etc/xray/domain | tr -d '[:space:]')"
elif [ -f /root/domain ]; then
  DOMAIN="$(head -n1 /root/domain | tr -d '[:space:]')"
  printf '%s\n' "$DOMAIN" > /etc/xray/domain
else
  read -r -p "Enter your domain: " DOMAIN
  [ -n "$DOMAIN" ] || die "Domain is empty."
  printf '%s\n' "$DOMAIN" > /etc/xray/domain
fi
ok "Domain: $DOMAIN"

# ------------------------------------------------------------
# Xray
# ------------------------------------------------------------
info "Downloading latest Xray..."
XRAY_TAG="$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name)"
[ -n "$XRAY_TAG" ] && [ "$XRAY_TAG" != "null" ] || die "Cannot determine Xray version."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fL "https://github.com/XTLS/Xray-core/releases/download/${XRAY_TAG}/Xray-linux-${XRAY_ARCH}.zip" \
  -o "$TMP/xray.zip"
unzip -oq "$TMP/xray.zip" -d "$TMP/xray"
install -m 0755 "$TMP/xray/xray" /usr/local/bin/xray
/usr/local/bin/xray version
ok "Xray installed."

# ------------------------------------------------------------
# Certificate
# ------------------------------------------------------------
if [ ! -s /etc/xray/xray.crt ] || [ ! -s /etc/xray/xray.key ]; then
  info "Obtaining certificate with acme.sh..."
  curl -fsSL https://get.acme.sh | sh -s email="admin@${DOMAIN}" || die "acme.sh install failed."
  export PATH="/root/.acme.sh:$PATH"
  systemctl stop nginx 2>/dev/null || true
  /root/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" --force || die "Certificate issuance failed."
  /root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --fullchain-file /etc/xray/xray.crt \
    --key-file /etc/xray/xray.key \
    --reloadcmd "systemctl reload nginx 2>/dev/null || true" || die "Certificate install failed."
fi
chmod 600 /etc/xray/xray.key
chmod 644 /etc/xray/xray.crt
ok "TLS certificate ready."

# ------------------------------------------------------------
# UUIDs / Reality keys
# ------------------------------------------------------------
UUID_VMESS_TLS="$(uuidgen)"
UUID_VLESS_TLS="$(uuidgen)"
UUID_TROJAN="$(uuidgen)"
UUID_VMESS_HTTP="$(uuidgen)"
UUID_VLESS_HTTP="$(uuidgen)"
UUID_VLESS_GRPC="$(uuidgen)"
UUID_TROJAN_GRPC="$(uuidgen)"
UUID_VLESS_XHTTP="$(uuidgen)"
UUID_VLESS_XHTTP_HTTP="$(uuidgen)"
UUID_REALITY="$(uuidgen)"
TROJANGO_PASSWORD="$(uuidgen)"

KEYS="$(/usr/local/bin/xray x25519)"
PRIVATE_KEY="$(printf '%s\n' "$KEYS" | awk -F': ' '/PrivateKey:|Private key:/ {print $2; exit}')"
PUBLIC_KEY="$(printf '%s\n' "$KEYS" | awk -F': ' '/Password:|PublicKey:|Public key:/ {print $2; exit}')"
[ -n "$PRIVATE_KEY" ] || die "Unable to generate/parse Reality private key."
[ -n "$PUBLIC_KEY" ] || warn "Could not parse Reality public key; inspect xray x25519 output."

SHORT_ID="$(openssl rand -hex 8)"

# ------------------------------------------------------------
# Base web page / Nginx
# ------------------------------------------------------------
cat > /var/www/html/index.html <<EOF
<!doctype html>
<html><head><meta charset="utf-8"><title>${DOMAIN}</title></head>
<body><h1>Welcome</h1></body></html>
EOF

# Nginx owns only internal ports. Public 80 is HAProxy; public
# 443/8443 are Xray. This removes the old port collisions.
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/akbar-xray.conf <<EOF
server {
    listen 127.0.0.1:8080;
    server_name ${DOMAIN} _;
    root /var/www/html;
    index index.html;

    location /vmess/ {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /vless/ {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /trojan/ {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
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
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
    }
    location /trojango/ {
        proxy_pass http://127.0.0.1:2087;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location / {
        try_files \$uri \$uri/ =404;
    }
}

# Xray Reality invalid-authentication target. This listener is TLS,
# while the normal Xray fallback goes to 8080 after TLS processing.
server {
    listen 127.0.0.1:8444 ssl;
    server_name ${DOMAIN} _;
    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
    location /trojango/ {
        proxy_pass http://127.0.0.1:2087;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

nginx -t
systemctl enable nginx
systemctl restart nginx

# ------------------------------------------------------------
# Xray config
# ------------------------------------------------------------
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
      "settings": {"clients": [{"id": "${UUID_VMESS_TLS}","alterId": 0}]},
      "streamSettings": {"network":"ws","security":"none","wsSettings":{"path":"/vmess/"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vless",
      "settings": {"clients":[{"id":"${UUID_VLESS_TLS}"}],"decryption":"none"},
      "streamSettings": {"network":"ws","security":"none","wsSettings":{"path":"/vless/"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "trojan",
      "settings": {"clients":[{"password":"${UUID_TROJAN}"}]},
      "streamSettings": {"network":"ws","security":"none","wsSettings":{"path":"/trojan/"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "vmess",
      "settings": {"clients":[{"id":"${UUID_VMESS_HTTP}","alterId":0}]},
      "streamSettings": {"network":"ws","security":"none","wsSettings":{"path":"/vmess-http/"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10005,
      "protocol": "vless",
      "settings": {"clients":[{"id":"${UUID_VLESS_HTTP}"}],"decryption":"none"},
      "streamSettings": {"network":"ws","security":"none","wsSettings":{"path":"/vless-http/"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10006,
      "protocol": "vless",
      "settings": {"clients":[{"id":"${UUID_VLESS_GRPC}"}],"decryption":"none"},
      "streamSettings": {"network":"grpc","security":"none","grpcSettings":{"serviceName":"vless-grpc"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10007,
      "protocol": "trojan",
      "settings": {"clients":[{"password":"${UUID_TROJAN_GRPC}"}]},
      "streamSettings": {"network":"grpc","security":"none","grpcSettings":{"serviceName":"trojan-grpc"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10008,
      "protocol": "vless",
      "settings": {"clients":[{"id":"${UUID_VLESS_XHTTP}"}],"decryption":"none"},
      "streamSettings": {"network":"xhttp","security":"none","xhttpSettings":{"path":"/xhttp/"}}
    },
    {
      "listen": "127.0.0.1",
      "port": 10009,
      "protocol": "vless",
      "settings": {"clients":[{"id":"${UUID_VLESS_XHTTP_HTTP}"}],"decryption":"none"},
      "streamSettings": {"network":"xhttp","security":"none","xhttpSettings":{"path":"/xhttp-http/"}}
    },

    {
      "listen": "127.0.0.1",
      "port": 10080,
      "protocol": "vless",
      "settings": {
        "clients": [{"id":"${UUID_REALITY}","flow":"xtls-rprx-vision"}],
        "decryption":"none",
        "fallbacks": [{"dest":8080}]
      },
      "streamSettings": {
        "network":"tcp",
        "security":"reality",
        "realitySettings": {
          "show":false,
          "target":"127.0.0.1:8444",
          "xver":0,
          "serverNames":["${DOMAIN}"],
          "privateKey":"${PRIVATE_KEY}",
          "shortIds":["${SHORT_ID}"]
        }
      }
    },

    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [{"id":"${UUID_REALITY}","flow":"xtls-rprx-vision"}],
        "decryption":"none",
        "fallbacks": [
          {"path":"/vmess/","dest":10001},
          {"path":"/vless/","dest":10002},
          {"path":"/trojan/","dest":10003},
          {"path":"/vmess-http/","dest":10004},
          {"path":"/vless-http/","dest":10005},
          {"path":"/grpc/","dest":10006},
          {"path":"/trojan-grpc/","dest":10007},
          {"path":"/xhttp/","dest":10008},
          {"path":"/xhttp-http/","dest":10009},
          {"path":"/ssh","dest":8880},
          {"path":"/ovpn-ws","dest":2086},
          {"dest":8080}
        ]
      },
      "streamSettings": {
        "network":"tcp",
        "security":"reality",
        "realitySettings": {
          "show":false,
          "target":"127.0.0.1:8444",
          "xver":0,
          "serverNames":["${DOMAIN}"],
          "privateKey":"${PRIVATE_KEY}",
          "shortIds":["${SHORT_ID}"]
        }
      }
    },

    {
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [{"id":"${UUID_REALITY}","flow":"xtls-rprx-vision"}],
        "decryption":"none",
        "fallbacks": [
          {"path":"/vmess/","dest":10001},
          {"path":"/vless/","dest":10002},
          {"path":"/trojan/","dest":10003},
          {"path":"/vmess-http/","dest":10004},
          {"path":"/vless-http/","dest":10005},
          {"path":"/grpc/","dest":10006},
          {"path":"/trojan-grpc/","dest":10007},
          {"path":"/xhttp/","dest":10008},
          {"path":"/xhttp-http/","dest":10009},
          {"path":"/ssh","dest":8880},
          {"path":"/ovpn-ws","dest":2086},
          {"dest":8080}
        ]
      },
      "streamSettings": {
        "network":"tcp",
        "security":"reality",
        "realitySettings": {
          "show":false,
          "target":"127.0.0.1:8444",
          "xver":0,
          "serverNames":["${DOMAIN}"],
          "privateKey":"${PRIVATE_KEY}",
          "shortIds":["${SHORT_ID}"]
        }
      }
    }
  ],
  "outbounds": [
    {"protocol":"freedom","tag":"direct"},
    {"protocol":"blackhole","tag":"blocked"}
  ],
  "routing": {
    "domainStrategy":"AsIs",
    "rules":[
      {"type":"field","protocol":["bittorrent"],"outboundTag":"blocked"}
    ]
  },
  "stats": {},
  "policy": {
    "levels":{"0":{"statsUserUplink":true,"statsUserDownlink":true}},
    "system":{"statsInboundUplink":true,"statsInboundDownlink":true}
  }
}
EOF

chmod 600 /etc/xray/config.json
/usr/local/bin/xray run -test -config /etc/xray/config.json || die "Xray configuration test failed."

cat > /etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=Xray Service By Akbar VPN
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=2
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# HAProxy: port 80 HTTP/TLS multiplexing
# ------------------------------------------------------------
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon
    maxconn 65535

defaults
    log global
    mode tcp
    timeout connect 5s
    timeout client  1h
    timeout server  1h

frontend public_80
    bind 0.0.0.0:80
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if HTTP
    use_backend http_plain if HTTP
    default_backend reality_80

backend http_plain
    mode tcp
    server nginx 127.0.0.1:8080 check

backend reality_80
    mode tcp
    server xray 127.0.0.1:10080 check
EOF

haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl enable haproxy
systemctl restart haproxy

# ------------------------------------------------------------
# Trojan-Go
# ------------------------------------------------------------
info "Installing Trojan-Go..."
TG_TAG="$(curl -fsSL https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest | jq -r .tag_name)"
[ -n "$TG_TAG" ] && [ "$TG_TAG" != "null" ] || die "Cannot determine Trojan-Go release."

TG_TMP="$(mktemp -d)"
case "$TG_ARCH" in
  amd64) TG_ASSET="trojan-go-linux-amd64.zip" ;;
  arm64) TG_ASSET="trojan-go-linux-arm64.zip" ;;
  armv7) TG_ASSET="trojan-go-linux-armv7.zip" ;;
esac

if ! curl -fL "https://github.com/p4gefau1t/trojan-go/releases/download/${TG_TAG}/${TG_ASSET}" \
    -o "$TG_TMP/trojan-go.zip"; then
  warn "Trojan-Go asset ${TG_ASSET} was not available for this architecture; Trojan-Go was not installed."
else
  unzip -oq "$TG_TMP/trojan-go.zip" -d "$TG_TMP/tg"
  TG_BIN="$(find "$TG_TMP/tg" -type f -name trojan-go -perm -u+x | head -n1 || true)"
  if [ -n "$TG_BIN" ]; then
    install -m 0755 "$TG_BIN" /usr/local/bin/trojan-go

    cat > /etc/trojan-go/config.json <<EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 2087,
  "remote_addr": "127.0.0.1",
  "remote_port": 89,
  "log_level": 1,
  "log_file": "/var/log/trojan-go/trojan-go.log",
  "password": ["${TROJANGO_PASSWORD}"],
  "disable_http_check": true,
  "udp_timeout": 60,
  "ssl": {
    "verify": false,
    "verify_hostname": false,
    "cert": "/etc/xray/xray.crt",
    "key": "/etc/xray/xray.key",
    "key_password": "",
    "sni": "${DOMAIN}",
    "alpn": ["http/1.1"],
    "session_ticket": true,
    "reuse_session": true
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
    "host": "${DOMAIN}"
  }
}
EOF

    printf '%s\n' "$TROJANGO_PASSWORD" > /etc/trojan-go/uuid.txt

    cat > /etc/systemd/system/trojan-go.service <<'EOF'
[Unit]
Description=Trojan-Go Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json
Restart=on-failure
RestartSec=2
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now trojan-go
    ok "Trojan-Go installed on TCP 2087."
  else
    warn "Trojan-Go binary not found in release archive."
  fi
fi
rm -rf "$TG_TMP"

# ------------------------------------------------------------
# Firewall
# ------------------------------------------------------------
for p in 22 80 443 8443 109 143 1194 2086 2087 990; do
  iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null ||
    iptables -I INPUT -p tcp --dport "$p" -j ACCEPT
done
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

systemctl daemon-reload
systemctl enable --now xray
systemctl restart xray

# Save credentials
cat > /etc/xray/akbar-info.txt <<EOF
DOMAIN=${DOMAIN}

REALITY_PORTS=80,443,8443
REALITY_UUID=${UUID_REALITY}
REALITY_PRIVATE_KEY=${PRIVATE_KEY}
REALITY_PUBLIC_KEY=${PUBLIC_KEY}
REALITY_SHORT_ID=${SHORT_ID}
REALITY_SNI=${DOMAIN}

VMESS_WS_UUID=${UUID_VMESS_TLS}
VLESS_WS_UUID=${UUID_VLESS_TLS}
TROJAN_WS_PASSWORD=${UUID_TROJAN}
VMESS_HTTP_UUID=${UUID_VMESS_HTTP}
VLESS_HTTP_UUID=${UUID_VLESS_HTTP}
VLESS_GRPC_UUID=${UUID_VLESS_GRPC}
TROJAN_GRPC_PASSWORD=${UUID_TROJAN_GRPC}
VLESS_XHTTP_UUID=${UUID_VLESS_XHTTP}
VLESS_XHTTP_HTTP_UUID=${UUID_VLESS_XHTTP_HTTP}

TROJANGO_PASSWORD=${TROJANGO_PASSWORD}
TROJANGO_PORT=2087
EOF
chmod 600 /etc/xray/akbar-info.txt

echo
ok "Installation completed."
echo "Configuration: /etc/xray/config.json"
echo "Credentials:    /etc/xray/akbar-info.txt"
echo
echo "Check:"
echo "  systemctl --no-pager --full status xray nginx haproxy trojan-go"
echo "  ss -lntp | grep -E ':(80|443|8443|2087)\\b'"
echo
