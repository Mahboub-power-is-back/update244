#!/bin/bash
set -euo pipefail
CONFIG=/etc/trojan-go/config.json; NGINX=/etc/nginx/conf.d/00-vpn-multiplex.conf; STATE=/etc/xray/paths.conf
[ -f "$CONFIG" ] || { echo 'Trojan-Go config not found'; exit 1; }
cur=$(python3 - "$CONFIG" <<'PY'
import json,sys; print(json.load(open(sys.argv[1])).get('websocket',{}).get('path','/trojango'))
PY
)
read -rp "Trojan-Go WebSocket path [$cur] : " path; path=${path:-$cur}
[[ "$path" == /* ]] || path="/$path"; [[ "$path" != */ ]] || path="${path%/}"
[[ "$path" == /* && "$path" != */ ]] && : || { echo "Invalid path"; exit 1; }
[[ "$path" != *" "* ]] || { echo "Invalid path"; exit 1; } || { echo 'Invalid path'; exit 1; }
python3 - "$CONFIG" "$path" <<'PY'
import json,sys,tempfile,os
p,path=sys.argv[1:]; d=json.load(open(p)); d.setdefault('websocket',{})['path']=path
fd,tmp=tempfile.mkstemp(prefix='.trgo.',dir=os.path.dirname(p))
with os.fdopen(fd,'w') as f: json.dump(d,f,indent=2); f.write('\n')
os.replace(tmp,p)
PY
python3 - "$NGINX" "$path" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); path=sys.argv[2]; s=p.read_text(); s=re.sub(r'location\s+/trojango\s*\{',f'location {path} {{',s); p.write_text(s)
PY
python3 - "$STATE" "$path" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); path=sys.argv[2]; lines=p.read_text().splitlines() if p.exists() else []
lines=[x for x in lines if not x.startswith('TROJAN_GO_PATH=')]; lines.append('TROJAN_GO_PATH='+path); p.write_text('\n'.join(lines)+'\n')
PY
/usr/local/bin/trojan-go -config "$CONFIG" >/dev/null 2>&1 || { echo 'Trojan-Go config validation failed'; exit 1; }
nginx -t; systemctl restart trojan-go.service; systemctl reload nginx
echo "MAHBOUB TUNNEL PREMIUM: Trojan-Go path $path"
