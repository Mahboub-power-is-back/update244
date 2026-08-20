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
  sed -i "/^#MT-vmess-${m}-/a\,{\"id\":\"${uuid}\",\"alterId\":0}" "$CONFIG"
done
printf "%s %s %s\n" "$user" "$exp" "$uuid" >> /etc/xray/vmess-accounts.db
systemctl restart xray.service
enc() { python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
pws=$(enc /vmess/); px=$(enc /vmess-xhttp/); ph=$(enc /vmess-httpupgrade/); pg=$(enc vmess-grpc)
vmess_link() {
  local port="$1" net="$2" tls="$3" path="$4"
  python3 - "$domain" "$port" "$uuid" "$user" "$net" "$tls" "$path" <<'PY2'
import base64,json,sys
host,port,uid,remark,net,tls,path=sys.argv[1:]
o={"v":"2","ps":remark,"add":host,"port":port,"id":uid,"aid":"0","scy":"auto","net":net,"type":"none","host":host,"path":path,"tls":tls}
if net=='grpc': o["path"]=path
print('vmess://'+base64.b64encode(json.dumps(o,separators=(',',':')).encode()).decode())
PY2
}
L_WS_TLS=$(vmess_link 443 ws tls /vmess/)
L_WS_NONE=$(vmess_link 80 ws none /vmess/)
L_X_TLS=$(vmess_link 443 xhttp tls /vmess-xhttp/)
L_X_NONE=$(vmess_link 80 xhttp none /vmess-xhttp/)
L_H_TLS=$(vmess_link 443 httpupgrade tls /vmess-httpupgrade/)
L_H_NONE=$(vmess_link 80 httpupgrade none /vmess-httpupgrade/)
L_G_TLS=$(vmess_link 443 grpc tls vmess-grpc)
L_G_NONE=$(vmess_link 80 grpc none vmess-grpc)
L_T_TLS=$(vmess_link 443 tcp tls /)
L_T_NONE=$(vmess_link 80 tcp none /)
echo "===== VMESS account ====="
echo "Created: $hariini  Expired: $exp"
echo "WS TLS    : $L_WS_TLS"
echo "WS NTLS   : $L_WS_NONE"
echo "XHTTP TLS : $L_X_TLS"
echo "XHTTP NTLS: $L_X_NONE"
echo "HU TLS    : $L_H_TLS"
echo "HU NTLS   : $L_H_NONE"
echo "gRPC TLS  : $L_G_TLS"
echo "gRPC NTLS : $L_G_NONE"
echo "TCP TLS   : $L_T_TLS"
echo "TCP NTLS  : $L_T_NONE"
