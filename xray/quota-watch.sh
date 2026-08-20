#!/bin/bash
set -euo pipefail
DB=/etc/xray/quota-accounts.db; CONFIG=/etc/xray/config.json; XRAY=/usr/local/bin/xray; API=127.0.0.1:10085
[ -s "$DB" ] || exit 0
while read -r user exp quota_gb ident; do
  [ -n "$user" ] && [ "${quota_gb:-0}" != 0 ] || continue
  bytes=$($XRAY api statsquery --server="$API" -pattern "user>>>${user}>>>traffic>>>" 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print(sum(int(x.get("value",0)) for x in d.get("stat",[])))' 2>/dev/null || echo 0)
  limit=$((quota_gb*1024*1024*1024))
  if [ "$bytes" -ge "$limit" ]; then
    python3 - "$CONFIG" "$user" "$ident" <<'PY'
import json,sys,tempfile,os
p,u,i=sys.argv[1:];d=json.load(open(p));changed=False
for ib in d.get('inbounds',[]):
 c=ib.get('settings',{}).get('clients',[]); new=[]
 for x in c:
  if x.get('email')==u or x.get('id')==i or x.get('password')==i or x.get('password')==u: changed=True
  else:new.append(x)
 ib.setdefault('settings',{})['clients']=new
if changed:
 fd,tmp=tempfile.mkstemp(prefix='.quota.',dir=os.path.dirname(p))
 with os.fdopen(fd,'w') as f:json.dump(d,f,indent=2);f.write('\n')
 os.replace(tmp,p)
PY
    systemctl restart xray.service >/dev/null 2>&1 || true
    mkdir -p /var/log/xray; echo "$(date -Is) quota-exceeded user=$user bytes=$bytes limit=$limit" >>/var/log/xray/quota.log
  fi
done <"$DB"
