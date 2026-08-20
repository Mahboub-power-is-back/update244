#!/bin/bash
set -euo pipefail
CONFIG=/etc/xray/config.json
NGINX=/etc/nginx/conf.d/00-vpn-multiplex.conf
STATE=/etc/xray/paths.conf
[ -f "$CONFIG" ] || { echo "Xray config not found"; exit 1; }
[ -f "$NGINX" ] || { echo "nginx multiplex config not found"; exit 1; }
valid(){ [[ "$1" == /* && "$1" == */ && "$1" != *" "* ]]; }
oldv=$(grep -E '^VLESS_WS_PATH=' "$STATE" 2>/dev/null|cut -d= -f2- || echo /vless/)
oldm=$(grep -E '^VMESS_WS_PATH=' "$STATE" 2>/dev/null|cut -d= -f2- || echo /vmess/)
oldt=$(grep -E '^TROJAN_WS_PATH=' "$STATE" 2>/dev/null|cut -d= -f2- || echo /trojan/)
read -rp "VLESS WS path [$oldv] : " v; v=${v:-$oldv}
read -rp "VMess WS path [$oldm] : " m; m=${m:-$oldm}
read -rp "Trojan WS path [$oldt] : " t; t=${t:-$oldt}
for p in "$v" "$m" "$t"; do valid "$p" || { echo "Invalid path: $p"; exit 1; }; done
python3 - "$CONFIG" "$v" "$m" "$t" <<'PY2'
import json,sys,tempfile,os
p,v,m,t=sys.argv[1:]; d=json.load(open(p))
for ib in d.get('inbounds',[]):
    ss=ib.get('streamSettings') or {}; ws=ss.get('wsSettings')
    if ss.get('network')!='ws' or not isinstance(ws,dict): continue
    port=ib.get('port'); tag=str(ib.get('tag','')).lower()
    if 'vless' in tag or port in (11011,11012): ws['path']=v
    elif 'vmess' in tag or port in (11001,11002): ws['path']=m
    elif 'trojan' in tag or port in (11021,11022): ws['path']=t
fd,tmp=tempfile.mkstemp(prefix='.xray.',dir=os.path.dirname(p))
with os.fdopen(fd,'w') as f: json.dump(d,f,indent=2); f.write('\n')
os.replace(tmp,p)
PY2
python3 - "$NGINX" "$v" "$m" "$t" <<'PY3'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); v,m,t=sys.argv[2:]; s=p.read_text()
s=re.sub(r'location\s+/vless/\s*\{',f'location {v} {{',s)
s=re.sub(r'location\s+/vmess/\s*\{',f'location {m} {{',s)
s=re.sub(r'location\s+/trojan/\s*\{',f'location {t} {{',s)
p.write_text(s)
PY3
mkdir -p /etc/xray
cat > "$STATE" <<EOF
VLESS_WS_PATH=$v
VMESS_WS_PATH=$m
TROJAN_WS_PATH=$t
SSH_WS_PATH=$(grep -E '^SSH_WS_PATH=' "$STATE" 2>/dev/null|cut -d= -f2- || echo /sshws/)
TROJAN_GO_PATH=$(grep -E '^TROJAN_GO_PATH=' "$STATE" 2>/dev/null|cut -d= -f2- || echo /trojango)
EOF
chmod 600 "$STATE"
/usr/local/bin/xray -test -config "$CONFIG"
nginx -t
systemctl restart xray.service
systemctl reload nginx
echo 'MAHBOUB TUNNEL PREMIUM: Xray paths updated.'
