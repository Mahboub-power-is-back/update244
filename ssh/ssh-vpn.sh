#!/bin/bash
# ============================================================
# AKBAR VPN - SSH / VPN / WEBSOCKET INSTALLER (CORRECTED)
#
# This script deliberately does NOT bind sslh to 443.
# Port 443 belongs to Xray's multiplexer.
#
# Public:
#   80/443/8443 -> Xray/Nginx multiplexing
#   SSH WS      -> /ssh on 80/443/8443
#   OVPN WS     -> /ovpn-ws on 80/443/8443
#
# Internal:
#   SSH WS       -> 8880
#   OVPN WS      -> 2086
#
# Other services:
#   OpenSSH      -> 22
#   Dropbear     -> 109,143
#   OpenVPN      -> 1194 TCP, 2200 UDP, 990 TCP
#   Squid        -> 3128
#   Nginx panel  -> 89 (optional legacy panel)
# ============================================================

set -Eeuo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[ "$EUID" -eq 0 ] || die "Run as root."
. /etc/os-release
case "${ID:-}" in ubuntu|debian) ;; *) die "Ubuntu/Debian only." ;; esac

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openssh-server dropbear openvpn nginx python3 python3-venv \
  squid curl wget unzip iptables iptables-persistent fail2ban

# ------------------------------------------------------------
# SSH / Dropbear
# ------------------------------------------------------------
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null || true

mkdir -p /etc/dropbear
if [ -f /etc/default/dropbear ]; then
  sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear || true
  sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=109/' /etc/default/dropbear || true
  grep -q '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear \
    && sed -i 's|^DROPBEAR_EXTRA_ARGS=.*|DROPBEAR_EXTRA_ARGS="-p 143"|' /etc/default/dropbear \
    || echo 'DROPBEAR_EXTRA_ARGS="-p 143"' >> /etc/default/dropbear
fi
systemctl enable dropbear 2>/dev/null || true
systemctl restart dropbear 2>/dev/null || warn "Dropbear is not running; continuing with OpenSSH/WS."

# ------------------------------------------------------------
# WebSocket helper scripts
# ------------------------------------------------------------
cat > /usr/local/bin/ws-nontls <<'PY'
#!/usr/bin/env python3
import socket,select,sys,threading
PORT=int(sys.argv[1]) if len(sys.argv)>1 else 8880
TARGET_DEFAULT="127.0.0.1:22"
BUF=16384
def header(data,name):
    try:
        for line in data.decode("latin1","ignore").split("\r\n"):
            if line.lower().startswith(name.lower()+":"):
                return line.split(":",1)[1].strip()
    except Exception:
        pass
    return ""
def relay(a,b):
    socks=[a,b]
    try:
        while True:
            r,_,e=select.select(socks,[],socks,60)
            if e or not r: return
            for s in r:
                d=s.recv(BUF)
                if not d: return
                (b if s is a else a).sendall(d)
    except Exception:
        return
def client(c):
    try:
        d=c.recv(BUF)
        target=header(d,"X-Real-Host") or TARGET_DEFAULT
        host,port=(target.rsplit(":",1)+[""])[:2] if ":" in target else (target,"22")
        if host not in ("127.0.0.1","localhost"):
            c.sendall(b"HTTP/1.1 403 Forbidden\r\n\r\n"); return
        s=socket.create_connection((host,int(port)),5)
        c.sendall(b"HTTP/1.1 101 Switching Protocols\r\n\r\n")
        relay(c,s)
    except Exception:
        pass
    finally:
        try:c.close()
        except:pass
def main():
    s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    s.bind(("127.0.0.1",PORT)); s.listen(256)
    while True:
        c,_=s.accept(); threading.Thread(target=client,args=(c,),daemon=True).start()
if __name__=="__main__": main()
PY
chmod 755 /usr/local/bin/ws-nontls

cat > /usr/local/bin/ws-ovpn <<'PY'
#!/usr/bin/env python3
import socket,select,sys,threading
PORT=int(sys.argv[1]) if len(sys.argv)>1 else 2086
TARGET=("127.0.0.1",1194)
BUF=16384
def relay(a,b):
    try:
        while True:
            r,_,e=select.select([a,b],[],[a,b],60)
            if e or not r:return
            for s in r:
                d=s.recv(BUF)
                if not d:return
                (b if s is a else a).sendall(d)
    except:pass
def client(c):
    try:
        d=c.recv(BUF)
        s=socket.create_connection(TARGET,5)
        c.sendall(b"HTTP/1.1 101 Switching Protocols\r\n\r\n")
        relay(c,s)
    except:pass
    finally:
        try:c.close()
        except:pass
def main():
    s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    s.bind(("127.0.0.1",PORT)); s.listen(256)
    while True:
        c,_=s.accept();threading.Thread(target=client,args=(c,),daemon=True).start()
if __name__=="__main__":main()
PY
chmod 755 /usr/local/bin/ws-ovpn

cat > /etc/systemd/system/ws-nontls.service <<'EOF'
[Unit]
Description=SSH WebSocket backend
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-nontls 8880
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/ws-ovpn.service <<'EOF'
[Unit]
Description=OpenVPN WebSocket backend
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-ovpn 2086
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ws-nontls ws-ovpn

# ------------------------------------------------------------
# Nginx: internal HTTP/WebSocket router. Public 80 is reached through HAProxy;
# public 443/8443 are reached through Xray fallbacks. Never bind public 443.
# ------------------------------------------------------------
mkdir -p /home/vps/public_html
if ! id vps >/dev/null 2>&1; then useradd -m vps; fi
chown -R www-data:www-data /home/vps/public_html

cat > /home/vps/public_html/index.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>Welcome</title></head>
<body><h1>Welcome</h1></body></html>
EOF

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/ssh-vpn.conf <<'EOF'
server {
    listen 127.0.0.1:8080;
    server_name _;

    root /home/vps/public_html;
    index index.html;

    location /ssh {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    location /ovpn-ws {
        proxy_pass http://127.0.0.1:2086;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

nginx -t
systemctl enable nginx
systemctl restart nginx

# ------------------------------------------------------------
# OpenVPN basic service if an existing config is present.
# We do not overwrite an existing provider/client setup.
# ------------------------------------------------------------
systemctl enable openvpn 2>/dev/null || true
systemctl restart openvpn 2>/dev/null || true

# ------------------------------------------------------------
# Squid: safe local default. Existing custom config is preserved.
# ------------------------------------------------------------
if [ ! -s /etc/squid/squid.conf ]; then
cat > /etc/squid/squid.conf <<'EOF'
http_port 3128
acl localhost src 127.0.0.1/32
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
http_access allow localhost
http_access allow localnet
http_access deny all
EOF
fi
systemctl enable --now squid || true

# ------------------------------------------------------------
# Fail2ban
# ------------------------------------------------------------
systemctl enable --now fail2ban || true

# ------------------------------------------------------------
# Firewall. Do not open 443 for another daemon: Xray owns it.
# ------------------------------------------------------------
for p in 22 80 443 8443 89 109 143 990 1194 2086 2087 3128; do
  iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null ||
    iptables -I INPUT -p tcp --dport "$p" -j ACCEPT
done
iptables -C INPUT -p udp --dport 1194 -j ACCEPT 2>/dev/null ||
  iptables -I INPUT -p udp --dport 1194 -j ACCEPT
iptables -C INPUT -p udp --dport 2200 -j ACCEPT 2>/dev/null ||
  iptables -I INPUT -p udp --dport 2200 -j ACCEPT
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

echo
ok "SSH/VPN/WebSocket setup completed."
echo "Public 80/443/8443 remain owned by the Xray/HAProxy multiplexing layer."
echo "SSH WebSocket backend: 127.0.0.1:8880"
echo "OpenVPN WebSocket backend: 127.0.0.1:2086"
echo "Dropbear: 109,143"
echo "OpenSSH: 22"
echo
echo "Check:"
echo "  ss -lntup | grep -E ':(80|443|8443|89|109|143|2086|2087)\\b'"
