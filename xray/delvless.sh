#!/bin/bash
set -euo pipefail
DB=/etc/xray/vless-accounts.db
CONFIG=/etc/xray/config.json
[ -s "$DB" ] || { echo "No vless accounts"; exit 1; }
nl -w2 -s ') ' "$DB"
read -rp "Select account number: " n
line=$(sed -n "${n}p" "$DB")
[ -n "$line" ] || exit 1
user=$(awk '{print $1}' <<<"$line")
exp=$(awk '{print $2}' <<<"$line")
uuid=$(awk '{print $3}' <<<"$line")
python3 - "$CONFIG" "$user" "$uuid" <<'PY2'
import re,sys
p,u,uid=sys.argv[1:]
s=open(p).read()
pat=r',\s*\{[^{}]*(?:"id"\s*:\s*"'+re.escape(uid)+r'"|"email"\s*:\s*"'+re.escape(u)+r'"|"password"\s*:\s*"'+re.escape(u)+r'")[^{}]*\}'
s=re.sub(pat,'',s)
open(p,'w').write(s)
PY2
sed -i "${n}d" "$DB"
systemctl restart xray.service
echo "Deleted $user ($exp)"
