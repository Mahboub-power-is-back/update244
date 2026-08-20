#!/bin/bash
set -euo pipefail
DB=/etc/xray/vless-accounts.db
[ -s "$DB" ] || { echo "No vless accounts"; exit 1; }
nl -w2 -s ') ' "$DB"
read -rp "Select account number: " n
read -rp "Add days: " days
line=$(sed -n "${n}p" "$DB")
user=$(awk '{print $1}' <<<"$line")
exp=$(awk '{print $2}' <<<"$line")
newexp=$(date -d "$exp + $days days" +%Y-%m-%d)
ident=$(awk '{print $3}' <<<"$line")
[ -n "$ident" ] || ident="$user"
sed -i "${n}c\$user $newexp $ident" "$DB"
echo "Renewed $user until $newexp"
