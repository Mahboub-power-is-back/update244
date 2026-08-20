#!/bin/bash
set -euo pipefail
MYIP=$(wget -qO- ipinfo.io/ip || true)
domain=$(cat /etc/xray/domain)
CONFIG=/etc/xray/config.json
read -rp "Username : " user
[[ "$user" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "Invalid value"; exit 1; }
if grep -Fq '"'$user'"' "$CONFIG"; then echo "Account already exists"; exit 1; fi
read -rp "Expired (Days) : " days
hariini=$(date +%Y-%m-%d)
exp=$(date -d "$days days" +%Y-%m-%d)
uuid=$(cat /proc/sys/kernel/random/uuid)
for m in ws xhttp httpupgrade grpc raw; do
  sed -i "/^#MT-vless-${m}-/a\,{\"id\":\"${uuid}\",\"email\":\"${user}\"}" "$CONFIG"
done
printf "%s %s %s\n" "$user" "$exp" "$uuid" >> /etc/xray/vless-accounts.db
systemctl restart xray.service
enc() { python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
pws=$(enc /vless/); px=$(enc /vless-xhttp/); ph=$(enc /vless-hu/); pg=$(enc vless-grpc)
if [ "vless" = "trojan" ]; then base="trojan://${user}@${domain}"; else base="vless://${uuid}@${domain}"; fi
echo "===== VLESS account ====="
echo "Created: $hariini  Expired: $exp"
echo "WS TLS    : $base:443?security=tls&type=ws&host=$domain&path=$pws&sni=$domain#$user"
echo "WS NTLS   : $base:80?security=none&type=ws&host=$domain&path=$pws#$user"
echo "XHTTP TLS : $base:443?security=tls&type=xhttp&host=$domain&path=$px&mode=auto&sni=$domain#$user"
echo "XHTTP NTLS: $base:80?security=none&type=xhttp&host=$domain&path=$px&mode=auto#$user"
echo "HU TLS    : $base:443?security=tls&type=httpupgrade&host=$domain&path=$ph&sni=$domain#$user"
echo "HU NTLS   : $base:80?security=none&type=httpupgrade&host=$domain&path=$ph#$user"
echo "gRPC TLS  : $base:443?security=tls&type=grpc&serviceName=$pg&sni=$domain#$user"
echo "gRPC NTLS : $base:80?security=none&type=grpc&serviceName=$pg#$user"
echo "TCP TLS   : $base:443?security=tls&type=tcp&sni=$domain#$user"
echo "TCP NTLS  : $base:80?security=none&type=tcp#$user"
