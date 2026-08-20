#!/bin/bash
set -euo pipefail
MYIP=$(wget -qO- ipinfo.io/ip || true)
domain=$(cat /etc/xray/domain)
CONFIG=/etc/xray/config.json
read -rp "Password : " user
[[ "$user" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "Invalid value"; exit 1; }
if grep -Fq '"'$user'"' "$CONFIG"; then echo "Account already exists"; exit 1; fi
read -rp "Expired (Days) : " days
read -rp "Usage quota (GB, 0=unlimited) : " quota_gb
[[ "$quota_gb" =~ ^[0-9]+$ ]] || { echo "Quota must be a whole number"; exit 1; }
hariini=$(date +%Y-%m-%d)
exp=$(date -d "$days days" +%Y-%m-%d)
uuid="$user"
for m in ws xhttp httpupgrade grpc raw; do
  sed -i "/^#MT-trojan-${m}-/a\,{\"password\":\"${user}\",\"email\":\"${user}\"}" "$CONFIG"
done
printf "%s %s %s\n" "$user" "$exp" "$user" >> /etc/xray/trojan-accounts.db
printf "%s %s %s %s\n" "$user" "$exp" "$quota_gb" "$user" >> /etc/xray/quota-accounts.db
systemctl restart xray.service
enc() { python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
pws=$(enc /trojan/); px=$(enc /trojan-xhttp/); ph=$(enc /trojan-hu/); pg=$(enc trojan-grpc)
if [ "trojan" = "trojan" ]; then base="trojan://${user}@${domain}"; else base="trojan://${uuid}@${domain}"; fi
echo "===== TROJAN account ====="
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
