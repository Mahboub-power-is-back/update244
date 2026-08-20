#!/bin/bash
# Proxy For Edukasi & Imclass
# My Telegram : https://t.me/Akbar218
# ==========================================
# Color
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'
# ==========================================
# Getting
MYIP=$(wget -qO- ipinfo.io/ip);
echo "Checking VPS"
IZIN=$( curl https://raw.githubusercontent.com/senowahyu62/perizinan/main/ipvps.txt | grep $MYIP )
if [ $MYIP = $MYIP ]; then
echo -e "${NC}${GREEN}Permission Accepted...${NC}"
else
echo -e "${NC}${RED}Permission Denied!${NC}";
echo -e "${NC}${LIGHT}Please Contact Admin!!"
echo -e "${NC}${LIGHT}Facebook : https://m.facebook.com/lis.tio.718"
echo -e "${NC}${LIGHT}WhatsApp : 081545854516"
echo -e "${NC}${LIGHT}Telegram : https://t.me/Akbar218"
exit 0
fi
# Link Hosting Kalian
akbarvpn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/websocket"

# Getting Proxy Template
wget -q -O /usr/local/bin/ws-nontls https://${akbarvpn}/websocket.py
chmod +x /usr/local/bin/ws-nontls

# Installing Service
cat > /etc/systemd/system/ws-nontls.service << END
[Unit]
Description=Python Proxy Mod By Akbar Maulana
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/python3 -O /usr/local/bin/ws-nontls 10088
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable ws-nontls
systemctl restart ws-nontls

# Getting Proxy Template
wget -q -O /usr/local/bin/ws-ovpn https://${akbarvpn}/ws-ovpn.py
chmod +x /usr/local/bin/ws-ovpn

# Installing Service
cat > /etc/systemd/system/ws-ovpn.service << END
[Unit]
Description=Python Proxy Mod By LamVpn
Documentation=https://t.me/LamVpn
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/python3 -O /usr/local/bin/ws-ovpn -b 127.0.0.1 -p 10086
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable ws-ovpn
systemctl restart ws-ovpn

# Getting Proxy Template
wget -q -O /usr/local/bin/ws-tls https://${akbarvpn}/ws-tls
chmod +x /usr/local/bin/ws-tls

# Installing Service
cat > /etc/systemd/system/ws-tls.service << END
[Unit]
Description=Python Proxy Mod By geovpn
Documentation=https://t.me/geovpn
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/python3 -O /usr/local/bin/ws-tls 10089
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable ws-tls
systemctl restart ws-tls


# ==========================================================
# HTTP/HTTPS multiplex frontend
# Public ports 80 and 443 are shared by Xray, SSH-WS,
# OpenVPN-WS and Trojan-Go. nginx terminates TLS on 443
# and routes by WebSocket path to private localhost backends.
# ==========================================================
mkdir -p /etc/nginx/conf.d
cat > /etc/nginx/conf.d/00-vpn-multiplex.conf <<'NGINX'
map $http_upgrade $connection_upgrade { default upgrade; '' close; }

upstream vmess_ws_tls { server 127.0.0.1:11001; }
upstream vmess_ws_none { server 127.0.0.1:11002; }
upstream vmess_xhttp_tls { server 127.0.0.1:11003; }
upstream vmess_xhttp_none { server 127.0.0.1:11004; }
upstream vmess_httpupgrade_tls { server 127.0.0.1:11005; }
upstream vmess_httpupgrade_none { server 127.0.0.1:11006; }
upstream vmess_grpc_tls { server 127.0.0.1:11007; }
upstream vmess_grpc_none { server 127.0.0.1:11008; }
upstream vmess_raw_tls { server 127.0.0.1:11009; }
upstream vmess_raw_none { server 127.0.0.1:11010; }
upstream vless_ws_tls { server 127.0.0.1:11011; }
upstream vless_ws_none { server 127.0.0.1:11012; }
upstream vless_xhttp_tls { server 127.0.0.1:11013; }
upstream vless_xhttp_none { server 127.0.0.1:11014; }
upstream vless_httpupgrade_tls { server 127.0.0.1:11015; }
upstream vless_httpupgrade_none { server 127.0.0.1:11016; }
upstream vless_grpc_tls { server 127.0.0.1:11017; }
upstream vless_grpc_none { server 127.0.0.1:11018; }
upstream vless_raw_tls { server 127.0.0.1:11019; }
upstream vless_raw_none { server 127.0.0.1:11020; }
upstream trojan_ws_tls { server 127.0.0.1:11021; }
upstream trojan_ws_none { server 127.0.0.1:11022; }
upstream trojan_xhttp_tls { server 127.0.0.1:11023; }
upstream trojan_xhttp_none { server 127.0.0.1:11024; }
upstream trojan_httpupgrade_tls { server 127.0.0.1:11025; }
upstream trojan_httpupgrade_none { server 127.0.0.1:11026; }
upstream trojan_grpc_tls { server 127.0.0.1:11027; }
upstream trojan_grpc_none { server 127.0.0.1:11028; }
upstream trojan_raw_tls { server 127.0.0.1:11029; }
upstream trojan_raw_none { server 127.0.0.1:11030; }
upstream trojango_ws { server 127.0.0.1:10087; }
upstream ssh_ws_tls { server 127.0.0.1:10089; }
upstream ssh_ws_none { server 127.0.0.1:10088; }

server {
    listen 80;
    server_name _;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    location /vmess/ { proxy_pass http://vmess_ws_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vmess-xhttp/ { proxy_pass http://vmess_xhttp_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vmess-httpupgrade/ { proxy_pass http://vmess_httpupgrade_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vless/ { proxy_pass http://vless_ws_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vless-xhttp/ { proxy_pass http://vless_xhttp_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vless-httpupgrade/ { proxy_pass http://vless_httpupgrade_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /trojan/ { proxy_pass http://trojan_ws_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /trojan-xhttp/ { proxy_pass http://trojan_xhttp_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /trojan-httpupgrade/ { proxy_pass http://trojan_httpupgrade_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vmess-grpc { grpc_pass grpc://vmess_grpc_none; grpc_set_header Host $host; }
    location /vless-grpc { grpc_pass grpc://vless_grpc_none; grpc_set_header Host $host; }
    location /trojan-grpc { grpc_pass grpc://trojan_grpc_none; grpc_set_header Host $host; }
    location /trojango { proxy_pass http://trojango_ws; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /ssh-ws { proxy_pass http://ssh_ws_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; proxy_set_header X-Real-Host 127.0.0.1:22; proxy_set_header X-Pass ""; }
    location /sshws/ { proxy_pass http://ssh_ws_none; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; proxy_set_header X-Real-Host 127.0.0.1:22; proxy_set_header X-Pass ""; }
    location / { root /home/vps/public_html; index index.html; }
}

server {
    listen 443 ssl;
    server_name _;
    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    location /vmess/ { proxy_pass http://vmess_ws_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vmess-xhttp/ { proxy_pass http://vmess_xhttp_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vmess-httpupgrade/ { proxy_pass http://vmess_httpupgrade_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vmess-grpc { grpc_pass grpc://vmess_grpc_tls; grpc_set_header Host $host; }
    location /vless/ { proxy_pass http://vless_ws_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vless-xhttp/ { proxy_pass http://vless_xhttp_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vless-httpupgrade/ { proxy_pass http://vless_httpupgrade_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /vless-grpc { grpc_pass grpc://vless_grpc_tls; grpc_set_header Host $host; }
    location /trojan/ { proxy_pass http://trojan_ws_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /trojan-xhttp/ { proxy_pass http://trojan_xhttp_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /trojan-httpupgrade/ { proxy_pass http://trojan_httpupgrade_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /trojango { proxy_pass http://trojango_ws; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; }
    location /ssh-ws { proxy_pass http://ssh_ws_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; proxy_set_header X-Real-Host 127.0.0.1:22; proxy_set_header X-Pass ""; }
    location /sshws/ { proxy_pass http://ssh_ws_tls; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; proxy_set_header X-Real-Host 127.0.0.1:22; proxy_set_header X-Pass ""; }
    location /trojan-grpc { grpc_pass grpc://trojan_grpc_tls; grpc_set_header Host $host; }
    location / { root /home/vps/public_html; index index.html; }
}


NGINX

# Wait briefly for the certificate generated by ins-xray.sh in the parallel installer.
for i in $(seq 1 60); do
    [ -s /etc/xray/xray.crt ] && [ -s /etc/xray/xray.key ] && break
    sleep 2
done
nginx -t && systemctl reload nginx || systemctl restart nginx

# Public multiplex ports.
for p in 80 443; do
    iptables -C INPUT -m state --state NEW -m tcp -p tcp --dport "$p" -j ACCEPT 2>/dev/null || \
      iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport "$p" -j ACCEPT
done
iptables-save > /etc/iptables.up.rules
netfilter-persistent save >/dev/null 2>&1 || true
