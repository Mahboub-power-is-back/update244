#!/bin/bash
set -euo pipefail
CONFIG=/etc/trojan-go/config.json; AKUN=/etc/trojan-go/akun.conf
[ -s "$CONFIG" ] || { echo 'Trojan-Go configuration is missing'; exit 1; }; mkdir -p /etc/trojan-go; touch "$AKUN"
domain=$(tr -d '[:space:]' </etc/xray/domain 2>/dev/null || true); [ -n "$domain" ] || domain=$(wget -qO- ipinfo.io/ip)
path=$(python3 - "$CONFIG" <<'PY'
import json,sys; print(json.load(open(sys.argv[1])).get('websocket',{}).get('path','/trojango'))
PY
)
while :; do read -rp 'Password : ' user; [[ "$user" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid password'; continue; }; grep -qE "^### ${user} " "$AKUN" && { echo 'User exists'; continue; }; break; done
read -rp 'Expired (Days) : ' days; [[ "$days" =~ ^[0-9]+$ ]] || exit 1
exp=$(date -d "+$days days" +%Y-%m-%d); today=$(date +%Y-%m-%d)
python3 - "$CONFIG" "$user" <<'PY'
import json,sys,tempfile,os
p,u=sys.argv[1:]; d=json.load(open(p)); a=d.setdefault('password',[])
if not isinstance(a,list): raise SystemExit('password must be an array')
if u not in a:a.append(u)
fd,tmp=tempfile.mkstemp(prefix='.trgo.',dir=os.path.dirname(p))
with os.fdopen(fd,'w') as f:json.dump(d,f,indent=2);f.write('\n')
os.replace(tmp,p)
PY
printf '### %s %s\n' "$user" "$exp" >> "$AKUN"
if ! systemctl restart trojan-go.service; then sed -i "\|^### ${user} ${exp}$|d" "$AKUN"; echo 'Restart failed; rolled back.'; exit 1; fi
enc(){ python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
h=$(enc "$domain"); p=$(enc "$path"); r=$(enc "$user")
link443="trojan-go://${user}@${domain}:443/?sni=${h}&type=ws&host=${h}&path=${p}&encryption=none#${r}"
link80="trojan-go://${user}@${domain}:80/?type=ws&host=${h}&path=${p}&encryption=none#${r}"
clear; cat <<EOF
================ MAHBOUB TUNNEL PREMIUM ================
Trojan-Go: $user
Address : $domain
Path    : $path
Created : $today
Expired : $exp
----------------------------------------------------------
Link 443: $link443
Link 80 : $link80
==========================================================
EOF
