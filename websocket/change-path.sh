#!/bin/bash
set -euo pipefail
NGINX=/etc/nginx/conf.d/00-vpn-multiplex.conf
STATE=/etc/xray/paths.conf
[ -f "$NGINX" ] || { echo "nginx multiplex config not found"; exit 1; }
cur=$(grep -E '^SSH_WS_PATH=' "$STATE" 2>/dev/null|cut -d= -f2- || echo /sshws/)
read -rp "SSH WebSocket path [$cur] : " path; path=${path:-$cur}
[[ "$path" == /* ]] || path="/$path"; [[ "$path" == */ ]] || path="$path/"
[[ "$path" == /* && "$path" != */ ]] && : || { echo "Invalid path"; exit 1; }
[[ "$path" != *" "* ]] || { echo "Invalid path"; exit 1; } || { echo 'Invalid path'; exit 1; }
python3 - "$NGINX" "$path" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); path=sys.argv[2]; s=p.read_text()
for proto in ('none','tls'):
    up=f'http://ssh_ws_{proto}'
    pat=r'location\s+/sshws/?\s*\{[^}]*\}'
    repl=f'location {path} {{ proxy_pass {up}; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_set_header Host $host; proxy_set_header X-Real-Host 127.0.0.1:22; proxy_set_header X-Pass ""; }}'
    s=re.sub(pat,repl,s,count=1)
p.write_text(s)
PY
python3 - "$STATE" "$path" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); path=sys.argv[2]; lines=p.read_text().splitlines() if p.exists() else []
lines=[x for x in lines if not x.startswith('SSH_WS_PATH=')]; lines.append('SSH_WS_PATH='+path); p.write_text('\n'.join(lines)+'\n')
PY
nginx -t && systemctl reload nginx
echo "MAHBOUB TUNNEL PREMIUM: SSH WS path $path"
