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

# MAHBOUB PROXY PREMIUM - local HTTP/CONNECT proxy on 8484
# This proxy is intentionally bound to localhost and is used by OHP as its
# HTTP proxy layer.  The existing Squid service on 3128 is left untouched.
if ! command -v python3 >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y python3
fi
install -m 0755 "${SCRIPT_DIR:-$(dirname "$0")}/mahboub-proxy.py" /usr/local/bin/mahboub-proxy.py
cat > /etc/systemd/system/mahboub-proxy.service << 'ENDPROXY'
[Unit]
Description=MAHBOUB PROXY PREMIUM - OHP HTTP Proxy 8484
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/mahboub-proxy.py --bind 127.0.0.1 --port 8484
Restart=on-failure
RestartSec=2
LimitNOFILE=65535
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
ENDPROXY

systemctl daemon-reload
systemctl enable --now mahboub-proxy.service

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
ExecStart=/usr/local/bin/ohpserver -port 8181 -proxy 127.0.0.1:8484 -tunnel 127.0.0.1:22
Restart=on-failure
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
END

# Dropbear OHP 8282
cat > /etc/systemd/system/dropbear-ohp.service << END
[Unit]]
Description=Dropbear OHP Redirection Service
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/ohpserver -port 8282 -proxy 127.0.0.1:8484 -tunnel 127.0.0.1:109
Restart=on-failure
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
END

# OpenVPN OHP 8383
cat > /etc/systemd/system/openvpn-ohp.service << END
[Unit]]
Description=OpenVPN OHP Redirection Service
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/ohpserver -port 8383 -proxy 127.0.0.1:8484 -tunnel 127.0.0.1:1194
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
printf 'MAHBOUB PROXY 8484: %s\n' "$(systemctl is-active mahboub-proxy.service)"
printf 'INSTALLATION COMPLETED !\n'
sleep 0.5
printf 'CHECKING LISTENING PORT\n'
if [ -n "$(ss -tupln | grep -w ':8484' | grep -E 'python3|mahboub-proxy')" ]
then
	echo 'MAHBOUB PROXY 8484 Running'
else
	echo 'MAHBOUB PROXY 8484 Not Found, please check manually'
fi
sleep 0.5
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
