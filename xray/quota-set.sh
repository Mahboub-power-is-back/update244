#!/bin/bash
set -euo pipefail
for db in /etc/xray/vless-accounts.db /etc/xray/vmess-accounts.db; do
 [ -f "$db" ] || continue; tmp=$(mktemp)
 while read -r u e i q; do [ -n "$u" ] || continue; printf '%s %s %s %s\n' "$u" "$e" "$i" "${q:-0}" >>"$tmp"; done <"$db"
 mv "$tmp" "$db"
done
echo 'Fourth field is quota in GB; 0 means unlimited. Copy selected rows to /etc/xray/quota-accounts.db to enforce.'
