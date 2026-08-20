#!/bin/bash
if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo "OpenVZ is not supported"
		exit 1
fi
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
# Link Hosting Kalian Untuk Ssh Vpn
akbarvpn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/ssh"
# Link Hosting Kalian Untuk Sstp
akbarvpnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/sstp"
# Link Hosting Kalian Untuk Ssr
akbarvpnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/ssr"
# Link Hosting Kalian Untuk Shadowsocks
akbarvpnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/shadowsocks"
# Link Hosting Kalian Untuk Wireguard
akbarvpnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/wireguard"
# Link Hosting Kalian Untuk Xray
akbarvpnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/xray"
# Link Hosting Kalian Untuk Ipsec
akbarvpnnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/ipsec"
# Link Hosting Kalian Untuk Backup
akbarvpnnnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/backup"
# Link Hosting Kalian Untuk Websocket
akbarvpnnnnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/websocket"
# Link Hosting Kalian Untuk Ohp
akbarvpnnnnnnnnnn="raw.githubusercontent.com/Mahboub-power-is-back/update244/refs/heads/main/ohp"

# Getting
MYIP=$(wget -qO- ipinfo.io/ip);
echo "Checking VPS"

# Bootstrap only the tools required to launch the existing installers on modern Ubuntu.
# The individual service installers keep their existing configuration logic.
export DEBIAN_FRONTEND=noninteractive
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y wget curl ca-certificates screen unzip cron git cmake make gcc g++ build-essential libpcre2-dev iptables iptables-persistent netfilter-persistent
fi

IZIN=$(wget -qO- ipinfo.io/ip);

rm -f setup.sh
clear
if [ -f "/etc/xray/domain" ]; then
echo "Script Already Installed"
exit 0
fi
mkdir /var/lib/akbarstorevpn;
echo "IP=" >> /var/lib/akbarstorevpn/ipvps.conf
wget https://${akbarvpn}/cf.sh && chmod +x cf.sh && ./cf.sh
#install v2ray
wget https://${akbarvpnnnnnn}/ins-xray.sh && chmod +x ins-xray.sh && screen -dmS xray ./ins-xray.sh
# Wait for Xray/ACME so the 443 nginx frontend can be installed reliably.
for i in $(seq 1 180); do
  if [ -s /etc/xray/xray.crt ] && [ -s /etc/xray/xray.key ] && systemctl is-active --quiet xray.service; then
    break
  fi
  sleep 2
done
#install ssh ovpn
wget https://${akbarvpn}/ssh-vpn.sh && chmod +x ssh-vpn.sh && screen -S ssh-vpn ./ssh-vpn.sh
wget https://${akbarvpnn}/sstp.sh && chmod +x sstp.sh && screen -S sstp ./sstp.sh
#install ssr
wget https://${akbarvpnnn}/ssr.sh && chmod +x ssr.sh && screen -S ssr ./ssr.sh
wget https://${akbarvpnnnn}/sodosok.sh && chmod +x sodosok.sh && screen -S ss ./sodosok.sh
#installwg
wget https://${akbarvpnnnnn}/wg.sh && chmod +x wg.sh && screen -S wg ./wg.sh
#install L2TP
wget https://${akbarvpnnnnnnn}/ipsec.sh && chmod +x ipsec.sh && screen -S ipsec ./ipsec.sh
wget https://${akbarvpnnnnnnnn}/set-br.sh && chmod +x set-br.sh && ./set-br.sh
# Websocket
wget https://${akbarvpnnnnnnnnn}/edu.sh && chmod +x edu.sh && ./edu.sh
# Ensure the public 80/443 multiplex configuration is present even if edu.sh
# was interrupted/restarted during a disconnected terminal session.
mkdir -p /etc/nginx/conf.d
wget -q -O /etc/nginx/conf.d/00-vpn-multiplex.conf "https://${akbarvpnnnnnnnnn}/nginx-multiplex.conf"
nginx -t && systemctl reload nginx
# Ohp Server
wget https://${akbarvpnnnnnnnnnn}/ohp.sh && chmod +x ohp.sh && ./ohp.sh

rm -f /root/ssh-vpn.sh
rm -f /root/sstp.sh
rm -f /root/wg.sh
rm -f /root/ss.sh
rm -f /root/ssr.sh
rm -f /root/ins-xray.sh
rm -f /root/ipsec.sh
rm -f /root/set-br.sh
rm -f /root/edu.sh
rm -f /root/ohp.sh
cat <<EOF> /etc/systemd/system/autosett.service
[Unit]
Description=autosetting
Documentation=https://t.me/Akbar218

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/set.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable autosett
wget -O /etc/set.sh "https://${akbarvpn}/set.sh"
chmod +x /etc/set.sh
history -c
echo "1.2" > /home/ver
echo " "
echo "Installation has been completed!!"
echo " "
echo "============================================================================" | tee -a log-install.txt
echo "" | tee -a log-install.txt
echo "----------------------------------------------------------------------------" | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "   >>> Service & Port"  | tee -a log-install.txt
echo "   - OpenSSH                 : 22"  | tee -a log-install.txt
echo "   - OpenVPN                 : TCP 1194, UDP 2200, SSL 990"  | tee -a log-install.txt
echo "   - Stunnel5                : 443, 445, 777"  | tee -a log-install.txt
echo "   - Dropbear                : 109, 143"  | tee -a log-install.txt
echo "   - Squid Proxy             : 3128, 8080"  | tee -a log-install.txt
echo "   - Badvpn                  : 7100, 7200, 7300"  | tee -a log-install.txt
echo "   - Nginx                   : 89"  | tee -a log-install.txt
echo "   - Wireguard               : 7070"  | tee -a log-install.txt
echo "   - L2TP/IPSEC VPN          : 1701"  | tee -a log-install.txt
echo "   - PPTP VPN                : 1732"  | tee -a log-install.txt
echo "   - SSTP VPN                : 444"  | tee -a log-install.txt
echo "   - Shadowsocks-R           : 1443-1543"  | tee -a log-install.txt
echo "   - SS-OBFS TLS             : 2443-2543"  | tee -a log-install.txt
echo "   - SS-OBFS HTTP            : 3443-3543"  | tee -a log-install.txt
echo "   - XRAYS VMess/VLESS/Trojan public transports : 80, 443"  | tee -a log-install.txt
echo "   - Trojan-Go WebSocket     : 443, 80 (/trojango)"  | tee -a log-install.txt
echo "   - SSH WebSocket           : 443, 80 (/ssh-ws)"  | tee -a log-install.txt
echo "   - udpcustom               : 1-65535"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "   >>> Server Information & Other Features"  | tee -a log-install.txt
echo "   - Timezone                : Asia/Jakarta (GMT +7)"  | tee -a log-install.txt
echo "   - Fail2Ban                : [ON]"  | tee -a log-install.txt
echo "   - Dflate                  : [ON]"  | tee -a log-install.txt
echo "   - IPtables                : [ON]"  | tee -a log-install.txt
echo "   - Auto-Reboot             : [ON]"  | tee -a log-install.txt
echo "   - IPv6                    : [OFF]"  | tee -a log-install.txt
echo "   - Autoreboot On 05.00 GMT +7" | tee -a log-install.txt
echo "   - Autobackup Data" | tee -a log-install.txt
echo "   - Restore Data" | tee -a log-install.txt
echo "   - Auto Delete Expired Account" | tee -a log-install.txt
echo "   - Full Orders For Various Services" | tee -a log-install.txt
echo "   - White Label" | tee -a log-install.txt
echo "   - Installation Log --> /root/log-install.txt"  | tee -a log-install.txt
echo " Reboot 15 Sec"
sleep 15
rm -f setup.sh
reboot
