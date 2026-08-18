#!/bin/bash

# Color
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'

MYIP=$(wget -qO- ipinfo.io/ip);
clear
domain=$(cat /etc/xray/domain)

apt install iptables iptables-persistent -y
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release -y
apt install socat cron bash-completion ntpdate -y

ntpdate pool.ntp.org

apt -y install chrony

timedatectl set-ntp true
systemctl enable chronyd && systemctl restart chronyd
systemctl enable chrony && systemctl restart chrony

timedatectl set-timezone Asia/Jakarta

chronyc sourcestats -v
chronyc tracking -v
date

# ============================================================
# Ambil Xray Core Version Terbaru
# ============================================================

latest_version="$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"

# ============================================================
# Installation Xray Core
# ============================================================

xraycore_link="https://github.com/XTLS/Xray-core/releases/download/v$latest_version/xray-linux-64.zip"

mkdir -p /usr/bin/xray
mkdir -p /etc/xray

cd "$(mktemp -d)"

curl -sL "$xraycore_link" -o xray.zip

unzip -q xray.zip
rm -rf xray.zip

mv xray /usr/local/bin/xray
chmod +x /usr/local/bin/xray

mkdir -p /var/log/xray/

# ============================================================
# Stop service using port 80 for ACME
# ============================================================

sudo lsof -t -i tcp:80 -s tcp:listen | sudo xargs -r kill

# ============================================================
# ACME
# ============================================================

cd /root/

wget https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh

bash acme.sh --install

rm -f acme.sh

cd /root/.acme.sh

bash acme.sh --register-account -m senowahyu62@gmail.com

bash acme.sh --issue \
    --standalone \
    -d "$domain" \
    --force

bash acme.sh --installcert \
    -d "$domain" \
    --fullchainpath /etc/xray/xray.crt \
    --keypath /etc/xray/xray.key

# ============================================================
# Squid
# ============================================================

service squid start 2>/dev/null || true

# ============================================================
# UUID
# ============================================================

uuid1=$(cat /proc/sys/kernel/random/uuid)
uuid2=$(cat /proc/sys/kernel/random/uuid)
uuid3=$(cat /proc/sys/kernel/random/uuid)
uuid4=$(cat /proc/sys/kernel/random/uuid)
uuid5=$(cat /proc/sys/kernel/random/uuid)
uuid6=$(cat /proc/sys/kernel/random/uuid)

# ============================================================
# Certificate File
# ============================================================

path_crt="/etc/xray/xray.crt"
path_key="/etc/xray/xray.key"

# ============================================================
# Xray Config
# ============================================================

cat > /etc/xray/config.json << END
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },

  "inbounds": [

    {
      "port": 8443,
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
        "security": "tls",

        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${path_crt}",
              "keyFile": "${path_key}"
            }
          ]
        },

        "tcpSettings": {},
        "kcpSettings": {},
        "httpSettings": {},

        "wsSettings": {
          "path": "/vmess/",
          "headers": {
            "Host": ""
          }
        },

        "quicSettings": {}
      }
    },

    {
      "port": 80,
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

        "tlsSettings": {},
        "tcpSettings": {},
        "kcpSettings": {},
        "httpSettings": {},

        "wsSettings": {
          "path": "/vmess/",
          "headers": {
            "Host": ""
          }
        },

        "quicSettings": {}
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
      "port": 8443,
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
        "security": "tls",

        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${path_crt}",
              "keyFile": "${path_key}"
            }
          ]
        },

        "tcpSettings": {},
        "kcpSettings": {},
        "httpSettings": {},

        "wsSettings": {
          "path": "/vless/",
          "headers": {
            "Host": ""
          }
        },

        "quicSettings": {}
      },

      "domain": "$domain",

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "port": 80,
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

        "tlsSettings": {},
        "tcpSettings": {},
        "kcpSettings": {},
        "httpSettings": {},

        "wsSettings": {
          "path": "/vless/",
          "headers": {
            "Host": ""
          }
        },

        "quicSettings": {}
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
      "port": 8443,
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
        "security": "tls",

        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${path_crt}",
              "keyFile": "${path_key}"
            }
          ],

          "alpn": [
            "http/1.1"
          ]
        },

        "tcpSettings": {},
        "kcpSettings": {},
        "httpSettings": {},

        "wsSettings": {
          "path": "/trojan/",
          "headers": {
            "Host": "$domain"
          }
        },

        "quicSettings": {},
        "grpcSettings": {}
      },

      "domain": "$domain",

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
# Xray Service
# ============================================================

cat > /etc/systemd/system/xray.service << END
[Unit]
Description=Xray Service By Akbar Maulana
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
User=root

CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

ExecStart=/usr/local/bin/xray -config /etc/xray/config.json

Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
END

# ============================================================
# Firewall - Xray
# ============================================================

iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8443 -j ACCEPT

iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 80 -j ACCEPT

iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 2083 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 2083 -j ACCEPT

iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules

netfilter-persistent save
netfilter-persistent reload

# ============================================================
# Start Xray
# ============================================================

systemctl daemon-reload

systemctl stop xray.service
systemctl start xray.service
systemctl enable xray.service
systemctl restart xray.service

# ============================================================
# Install Trojan Go
# ============================================================

latest_version="$(curl -s "https://api.github.com/repos/p4gefau1t/trojan-go/releases" | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"

trojango_link="https://github.com/p4gefau1t/trojan-go/releases/download/v${latest_version}/trojan-go-linux-amd64.zip"

mkdir -p "/usr/bin/trojan-go"
mkdir -p "/etc/trojan-go"

cd "$(mktemp -d)"

curl -sL "${trojango_link}" -o trojan-go.zip

unzip -q trojan-go.zip

rm -rf trojan-go.zip

mv trojan-go /usr/local/bin/trojan-go

chmod +x /usr/local/bin/trojan-go

mkdir -p /var/log/trojan-go/

touch /etc/trojan-go/akun.conf
touch /var/log/trojan-go/trojan-go.log

# ============================================================
# Trojan Go Config
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
    "$uuid6"
  ],

  "disable_http_check": true,
  "udp_timeout": 60,

  "ssl": {
    "verify": false,
    "verify_hostname": false,

    "cert": "/etc/xray/xray.crt",
    "key": "/etc/xray/xray.key",

    "key_password": "",

    "cipher": "",
    "curves": "",

    "prefer_server_cipher": false,

    "sni": "$domain",

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
    "host": "$domain"
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
# Trojan Go Service
# ============================================================

cat > /etc/systemd/system/trojan-go.service << END
[Unit]
Description=Trojan-Go Service By Akbar Maulana
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
User=root

CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json

Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
END

# ============================================================
# Trojan Go UUID
# ============================================================

cat > /etc/trojan-go/uuid.txt << END
$uuid6
END

# ============================================================
# Trojan Go Firewall
# ============================================================

iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 2086 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 2087 -j ACCEPT

iptables-save > /etc/iptables.up.rules

iptables-restore -t < /etc/iptables.up.rules

netfilter-persistent save
netfilter-persistent reload

# ============================================================
# Restart Trojan Go
# ============================================================

systemctl daemon-reload

systemctl stop trojan-go
systemctl start trojan-go
systemctl enable trojan-go
systemctl restart trojan-go

# ============================================================
# Copy Domain
# ============================================================

cd

if [[ -f /root/domain ]]; then
    cp /root/domain /etc/xray/
fi

# ============================================================
# DONE
# ============================================================

echo
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN} Installation completed${NC}"
echo -e "${GREEN}==============================================${NC}"
echo
echo "Domain: $domain"
echo
echo "VMess TLS     : 8443 /vmess/"
echo "VMess non-TLS : 80 /vmess/"
echo "VLESS TLS     : 8443 /vless/"
echo "VLESS non-TLS : 80 /vless/"
echo "Trojan WS TLS : 8443 /trojan/"
echo "Trojan-Go WS  : 2087 /trojango"
echo
echo "VMess UUID     : $uuid1"
echo "VMess NT UUID  : $uuid2"
echo "VLESS UUID     : $uuid3"
echo "VLESS NT UUID  : $uuid4"
echo "Trojan Pass    : $uuid5"
echo "Trojan-Go Pass : $uuid6"
echo
echo -e "${ORANGE}Note: VMess, VLESS and Trojan are configured on the same${NC}"
echo -e "${ORANGE}TLS port 8443, so Xray cannot bind all three separately.${NC}"
echo -e "${ORANGE}The WS paths are /vmess/, /vless/ and /trojan/.${NC}"
echo
echo -e "${GREEN}==============================================${NC}"
