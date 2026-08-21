#!/bin/bash
# Ohp Script
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

# Download File Ohp
wget https://raw.githubusercontent.com/tcatvpn/scriptvps/main/ohp/ohpserver
chmod +x ohpserver
cp ohpserver /usr/local/bin/ohpserver
/bin/rm -rf ohpserver*

# MAHBOUB PROXY MODES
# 01 = OVPN / SSH Python tunnel (X-Real-Host style)
# 02 = Direct HTTP/CONNECT proxy
# Both modes use public port 80; the menu makes them mutually exclusive.
for f in mahboub-http-tunnel.py mahboub-proxy.py; do
    if [ -f "/root/$f" ]; then
        cp "/root/$f" "/usr/local/bin/$f"
        chmod +x "/usr/local/bin/$f"
    fi
done

cat > /etc/systemd/system/http-tunnel.service << 'END_HTTP_TUNNEL'
[Unit]
Description=MAHBOUB PROXY - OVPN SSH Python Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/mahboub-http-tunnel.py --bind 0.0.0.0 --port 80
Restart=on-failure
RestartSec=2
LimitNOFILE=65535
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
END_HTTP_TUNNEL

cat > /etc/systemd/system/mahboub-proxy.service << 'END_DIRECT_PROXY'
[Unit]
Description=MAHBOUB PROXY - Direct HTTP CONNECT Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/mahboub-proxy.py --bind 0.0.0.0 --port 80
Restart=on-failure
RestartSec=2
LimitNOFILE=65535
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
END_DIRECT_PROXY

systemctl daemon-reload
systemctl disable --now http-tunnel.service >/dev/null 2>&1 || true
systemctl disable --now mahboub-proxy.service >/dev/null 2>&1 || true

# Installing Service
# SSH OHP Port 8181
cat > /etc/systemd/system/ssh-ohp.service << END
[Unit]
Description=SSH OHP Redirection Service
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/ohpserver -port 8181 -proxy 127.0.0.1:3128 -tunnel 127.0.0.1:22
Restart=on-failure
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
END

# Dropbear OHP 8282
cat > /etc/systemd/system/dropbear-ohp.service << END
[Unit]
Description=Dropbear OHP Redirection Service
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/ohpserver -port 8282 -proxy 127.0.0.1:3128 -tunnel 127.0.0.1:109
Restart=on-failure
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
END

# OpenVPN OHP 8383
cat > /etc/systemd/system/openvpn-ohp.service << END
[Unit]
Description=OpenVPN OHP Redirection Service
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/ohpserver -port 8383 -proxy 127.0.0.1:3128 -tunnel 127.0.0.1:1194
Restart=on-failure
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable ssh-ohp
systemctl restart ssh-ohp
systemctl enable dropbear-ohp
systemctl restart dropbear-ohp
systemctl enable openvpn-ohp
systemctl restart openvpn-ohp
#------------------------------
printf 'INSTALLATION COMPLETED !\n'
sleep 0.5
printf 'CHECKING LISTENING PORT\n'
if [ -n "$(ss -tupln | grep ohpserver | grep -w 8181)" ]
then
	echo 'SSH OHP Redirection Running'
else
	echo 'SSH OHP Redirection Not Found, please check manually'
fi
sleep 0.5
if [ -n "$(ss -tupln | grep ohpserver | grep -w 8282)" ]
then
	echo 'Dropbear OHP Redirection Running'
else
	echo 'Dropbear OHP Redirection Not Found, please check manually'
fi
sleep 0.5
if [ -n "$(ss -tupln | grep ohpserver | grep -w 8383)" ]
then
	echo 'OpenVPN OHP Redirection Running'
else
	echo 'OpenVPN OHP Redirection Not Found, please check manually'
fi
sleep 0.5
