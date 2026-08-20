#!/bin/bash

# Color
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'

MYIP=$(wget -qO- ipinfo.io/ip);
clear
domain=$(cat /etc/xray/domain)
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y iptables iptables-persistent curl socat xz-utils wget ca-certificates apt-transport-https gnupg dnsutils lsb-release cron bash-completion unzip
apt -y install chrony
timedatectl set-ntp true
systemctl enable --now chrony 2>/dev/null || systemctl enable --now chronyd 2>/dev/null || true
timedatectl set-timezone Asia/Jakarta
chronyc sourcestats -v
chronyc tracking -v
date

# / / Ambil Xray Core Version Terbaru
latest_version="$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"

# / / Installation Xray Core
xraycore_link="https://github.com/XTLS/Xray-core/releases/download/v$latest_version/Xray-linux-64.zip"

# / / Make Main Directory
mkdir -p /usr/bin/xray
mkdir -p /etc/xray

# / / Unzip Xray Linux 64
cd `mktemp -d`
curl -sL "$xraycore_link" -o xray.zip
unzip -q xray.zip && rm -rf xray.zip
mv xray /usr/local/bin/xray
chmod +x /usr/local/bin/xray

# Make Folder XRay
mkdir -p /var/log/xray/

systemctl stop nginx 2>/dev/null || true
systemctl stop xray.service 2>/dev/null || true
cd /root/
wget https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh
bash acme.sh --install
rm acme.sh
cd .acme.sh
bash acme.sh --register-account -m senowahyu62@gmail.com || true
if ! bash acme.sh --issue --standalone -d "$domain" --force; then
  echo "ERROR: ACME certificate issuance failed for $domain." >&2
  exit 1
fi
if ! bash acme.sh --installcert -d "$domain" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key; then
  echo "ERROR: ACME certificate installation failed." >&2
  exit 1
fi
chmod 600 /etc/xray/xray.key
chmod 644 /etc/xray/xray.crt

service squid start
# One UUID per Xray account: the same UUID is accepted by VMess, VLESS and Trojan.
# The initial/admin Xray account also uses one shared UUID across all three protocols.
xray_uuid=$(cat /proc/sys/kernel/random/uuid)
trojango_uuid=$(cat /proc/sys/kernel/random/uuid)
printf '%s\n' "$xray_uuid" > /etc/xray/default-uuid
chmod 600 /etc/xray/default-uuid

# // Certificate File
path_crt="/etc/xray/xray.crt"
path_key="/etc/xray/xray.key"

# Buat Config Xray
cat > /etc/xray/config.json << END
{
  "log":{"access":"/var/log/xray/access.log","error":"/var/log/xray/error.log","loglevel":"info"},
  "inbounds":[
    {"listen":"127.0.0.1","port":11001,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-ws-tls
]},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/vmess/","headers":{"Host":""}}}},
    {"listen":"127.0.0.1","port":11002,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-ws-none
]},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/vmess/","headers":{"Host":""}}}},
    {"listen":"127.0.0.1","port":11003,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-xhttp-tls
]},"streamSettings":{"network":"xhttp","security":"none","xhttpSettings":{"path":"/vmess-xhttp/","mode":"auto"}}},
    {"listen":"127.0.0.1","port":11004,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-xhttp-none
]},"streamSettings":{"network":"xhttp","security":"none","xhttpSettings":{"path":"/vmess-xhttp/","mode":"auto"}}},
    {"listen":"127.0.0.1","port":11005,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-httpupgrade-tls
]},"streamSettings":{"network":"httpupgrade","security":"none","httpupgradeSettings":{"path":"/vmess-hu/","host":""}}},
    {"listen":"127.0.0.1","port":11006,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-httpupgrade-none
]},"streamSettings":{"network":"httpupgrade","security":"none","httpupgradeSettings":{"path":"/vmess-hu/","host":""}}},
    {"listen":"127.0.0.1","port":11007,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-grpc-tls
]},"streamSettings":{"network":"grpc","security":"none","grpcSettings":{"serviceName":"vmess-grpc","multiMode":false}}},
    {"listen":"127.0.0.1","port":11008,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-grpc-none
]},"streamSettings":{"network":"grpc","security":"none","grpcSettings":{"serviceName":"vmess-grpc","multiMode":false}}},
    {"listen":"0.0.0.0","port":11009,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-raw-tls
]},"streamSettings":{"network":"raw","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"${path_crt}","keyFile":"${path_key}"}]}}},
    {"listen":"0.0.0.0","port":11010,"protocol":"vmess","settings":{"clients":[{"id":"${xray_uuid}","alterId":0}
#MT-vmess-raw-none
]},"streamSettings":{"network":"raw","security":"none"}},
    {"listen":"127.0.0.1","port":11011,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-ws-tls
],"decryption":"none"},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/vless/","headers":{"Host":""}}}},
    {"listen":"127.0.0.1","port":11012,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-ws-none
],"decryption":"none"},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/vless/","headers":{"Host":""}}}},
    {"listen":"127.0.0.1","port":11013,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-xhttp-tls
],"decryption":"none"},"streamSettings":{"network":"xhttp","security":"none","xhttpSettings":{"path":"/vless-xhttp/","mode":"auto"}}},
    {"listen":"127.0.0.1","port":11014,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-xhttp-none
],"decryption":"none"},"streamSettings":{"network":"xhttp","security":"none","xhttpSettings":{"path":"/vless-xhttp/","mode":"auto"}}},
    {"listen":"127.0.0.1","port":11015,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-httpupgrade-tls
],"decryption":"none"},"streamSettings":{"network":"httpupgrade","security":"none","httpupgradeSettings":{"path":"/vless-hu/","host":""}}},
    {"listen":"127.0.0.1","port":11016,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-httpupgrade-none
],"decryption":"none"},"streamSettings":{"network":"httpupgrade","security":"none","httpupgradeSettings":{"path":"/vless-hu/","host":""}}},
    {"listen":"127.0.0.1","port":11017,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-grpc-tls
],"decryption":"none"},"streamSettings":{"network":"grpc","security":"none","grpcSettings":{"serviceName":"vless-grpc","multiMode":false}}},
    {"listen":"127.0.0.1","port":11018,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-grpc-none
],"decryption":"none"},"streamSettings":{"network":"grpc","security":"none","grpcSettings":{"serviceName":"vless-grpc","multiMode":false}}},
    {"listen":"0.0.0.0","port":11019,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-raw-tls
],"decryption":"none"},"streamSettings":{"network":"raw","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"${path_crt}","keyFile":"${path_key}"}]}}},
    {"listen":"0.0.0.0","port":11020,"protocol":"vless","settings":{"clients":[{"id":"${xray_uuid}","email":""}
#MT-vless-raw-none
],"decryption":"none"},"streamSettings":{"network":"raw","security":"none"}},
    {"listen":"127.0.0.1","port":11021,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-ws-tls
]},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/trojan/","headers":{"Host":""}}}},
    {"listen":"127.0.0.1","port":11022,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-ws-none
]},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/trojan/","headers":{"Host":""}}}},
    {"listen":"127.0.0.1","port":11023,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-xhttp-tls
]},"streamSettings":{"network":"xhttp","security":"none","xhttpSettings":{"path":"/trojan-xhttp/","mode":"auto"}}},
    {"listen":"127.0.0.1","port":11024,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-xhttp-none
]},"streamSettings":{"network":"xhttp","security":"none","xhttpSettings":{"path":"/trojan-xhttp/","mode":"auto"}}},
    {"listen":"127.0.0.1","port":11025,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-httpupgrade-tls
]},"streamSettings":{"network":"httpupgrade","security":"none","httpupgradeSettings":{"path":"/trojan-hu/","host":""}}},
    {"listen":"127.0.0.1","port":11026,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-httpupgrade-none
]},"streamSettings":{"network":"httpupgrade","security":"none","httpupgradeSettings":{"path":"/trojan-hu/","host":""}}},
    {"listen":"127.0.0.1","port":11027,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-grpc-tls
]},"streamSettings":{"network":"grpc","security":"none","grpcSettings":{"serviceName":"trojan-grpc","multiMode":false}}},
    {"listen":"127.0.0.1","port":11028,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-grpc-none
]},"streamSettings":{"network":"grpc","security":"none","grpcSettings":{"serviceName":"trojan-grpc","multiMode":false}}},
    {"listen":"0.0.0.0","port":11029,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-raw-tls
]},"streamSettings":{"network":"raw","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"${path_crt}","keyFile":"${path_key}"}]}}},
    {"listen":"0.0.0.0","port":11030,"protocol":"trojan","settings":{"clients":[{"password":"${xray_uuid}","email":""}
#MT-trojan-raw-none
]},"streamSettings":{"network":"raw","security":"none"}}
  ],
  "outbounds":[{"protocol":"freedom","settings":{}},{"protocol":"blackhole","settings":{},"tag":"blocked"}],
  "routing":{"rules":[{"type":"field","ip":["0.0.0.0/8","10.0.0.0/8","100.64.0.0/10","169.254.0.0/16","172.16.0.0/12","192.168.0.0/16","::1/128","fc00::/7","fe80::/10"],"outboundTag":"blocked"},{"type":"field","outboundTag":"blocked","protocol":["bittorrent"]}]},
  "stats":{},"policy":{"levels":{"0":{"statsUserDownlink":true,"statsUserUplink":true}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}}
}
END

# Unified Xray account manager.
# One account = one UUID shared by VMess, VLESS and Trojan.
cat > /usr/local/bin/xray-account <<'XRAYACCOUNT'
#!/bin/bash
set -euo pipefail

CONFIG=/etc/xray/config.json
DB=/etc/xray/xray-accounts.db
VMDB=/etc/xray/vmess-accounts.db
VLDB=/etc/xray/vless-accounts.db
TRDB=/etc/xray/trojan-accounts.db
DOMAIN_FILE=/etc/xray/domain

die(){ echo "ERROR: $*" >&2; exit 1; }
[ -s "$CONFIG" ] || die "Xray config not found: $CONFIG"
[ -s "$DOMAIN_FILE" ] || die "Xray domain not found: $DOMAIN_FILE"
domain=$(cat "$DOMAIN_FILE")

save_db_line(){
    local db="$1" line="$2"
    touch "$db"
    grep -Fqx "$line" "$db" 2>/dev/null || printf '%s\n' "$line" >> "$db"
}

add_account(){
    read -rp "Username : " user
    [[ "$user" =~ ^[A-Za-z0-9_.-]+$ ]] || die "Invalid username"
    if [ -f "$DB" ] && grep -Fq "$user " "$DB"; then
        die "Account already exists: $user"
    fi
    read -rp "Expired (Days) : " days
    [[ "$days" =~ ^[0-9]+$ ]] || die "Days must be a number"
    exp=$(date -d "+${days} days" +%Y-%m-%d)
    uuid=$(cat /proc/sys/kernel/random/uuid)

    python3 - "$CONFIG" "$user" "$uuid" <<'PY'
import json,sys,tempfile,os
p,user,uid=sys.argv[1:]
with open(p) as f: d=json.load(f)

protocols={"vmess","vless","trojan"}
found_uid=None
for ib in d.get("inbounds",[]):
    if ib.get("protocol") not in protocols: continue
    for c in ib.get("settings",{}).get("clients",[]) or []:
        if c.get("email")==user:
            found_uid=c.get("id") or c.get("password")
            break
    if found_uid: break

if found_uid:
    uid=found_uid

for ib in d.get("inbounds",[]):
    proto=ib.get("protocol")
    if proto not in protocols: continue
    clients=ib.setdefault("settings",{}).setdefault("clients",[])
    # Remove accidental duplicate entries for this account in the same inbound.
    clients[:] = [c for c in clients if c.get("email") != user]
    if proto=="vmess":
        clients.append({"id":uid,"alterId":0,"email":user})
    elif proto=="vless":
        clients.append({"id":uid,"email":user})
    else:
        clients.append({"password":uid,"email":user})

fd,tmp=tempfile.mkstemp(prefix=".xray.",dir=os.path.dirname(p))
with os.fdopen(fd,"w") as f:
    json.dump(d,f,indent=2)
    f.write("\n")
os.replace(tmp,p)
print(uid)
PY
    uuid=$(python3 - "$CONFIG" "$user" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); u=sys.argv[2]
for ib in d.get("inbounds",[]):
    for c in ib.get("settings",{}).get("clients",[]) or []:
        if c.get("email")==u:
            print(c.get("id") or c.get("password")); raise SystemExit
raise SystemExit(1)
PY
)

    line="$user $exp $uuid"
    save_db_line "$DB" "$line"
    save_db_line "$VMDB" "$line"
    save_db_line "$VLDB" "$line"
    save_db_line "$TRDB" "$line"

    /usr/local/bin/xray run -test -config "$CONFIG" >/dev/null
    systemctl restart xray.service

    enc(){ python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
    vws=$(enc /vless/); vx=$(enc /vless-xhttp/); vh=$(enc /vless-hu/); vg=$(enc vless-grpc)
    mws=$(enc /vmess/); mx=$(enc /vmess-xhttp/); mh=$(enc /vmess-httpupgrade/); mg=$(enc vmess-grpc)
    tws=$(enc /trojan/); tx=$(enc /trojan-xhttp/); th=$(enc /trojan-hu/); tg=$(enc trojan-grpc)

    echo
    echo "===== XRAY ACCOUNT ====="
    echo "User     : $user"
    echo "Expires  : $exp"
    echo "UUID     : $uuid"
    echo
    echo "VLESS"
    echo "WS TLS    : vless://${uuid}@${domain}:443?security=tls&type=ws&host=${domain}&path=${vws}&sni=${domain}#${user}"
    echo "WS NTLS   : vless://${uuid}@${domain}:80?security=none&type=ws&host=${domain}&path=${vws}#${user}"
    echo "XHTTP TLS : vless://${uuid}@${domain}:443?security=tls&type=xhttp&host=${domain}&path=${vx}&mode=auto&sni=${domain}#${user}"
    echo "XHTTP NTLS: vless://${uuid}@${domain}:80?security=none&type=xhttp&host=${domain}&path=${vx}&mode=auto#${user}"
    echo "HU TLS    : vless://${uuid}@${domain}:443?security=tls&type=httpupgrade&host=${domain}&path=${vh}&sni=${domain}#${user}"
    echo "HU NTLS   : vless://${uuid}@${domain}:80?security=none&type=httpupgrade&host=${domain}&path=${vh}#${user}"
    echo "gRPC TLS  : vless://${uuid}@${domain}:443?security=tls&type=grpc&serviceName=${vg}&sni=${domain}#${user}"
    echo "gRPC NTLS : vless://${uuid}@${domain}:80?security=none&type=grpc&serviceName=${vg}#${user}"
    echo "TCP TLS   : vless://${uuid}@${domain}:11019?security=tls&type=tcp&sni=${domain}#${user}"
    echo "TCP NTLS  : vless://${uuid}@${domain}:11020?security=none&type=tcp#${user}"
    echo
    echo "VMESS"
    vmess_link(){
      local port="$1" net="$2" tls="$3" path="$4"
      python3 - "$domain" "$port" "$uuid" "$user" "$net" "$tls" "$path" <<'PY'
import base64,json,sys
host,port,uid,remark,net,tls,path=sys.argv[1:]
o={"v":"2","ps":remark,"add":host,"port":port,"id":uid,"aid":"0","scy":"auto","net":net,"type":"none","host":host,"path":path,"tls":tls}
print("vmess://"+base64.b64encode(json.dumps(o,separators=(",",":")).encode()).decode())
PY
    }
    echo "WS TLS    : $(vmess_link 443 ws tls /vmess/)"
    echo "WS NTLS   : $(vmess_link 80 ws none /vmess/)"
    echo "XHTTP TLS : $(vmess_link 443 xhttp tls /vmess-xhttp/)"
    echo "XHTTP NTLS: $(vmess_link 80 xhttp none /vmess-xhttp/)"
    echo "HU TLS    : $(vmess_link 443 httpupgrade tls /vmess-httpupgrade/)"
    echo "HU NTLS   : $(vmess_link 80 httpupgrade none /vmess-httpupgrade/)"
    echo "gRPC TLS  : $(vmess_link 443 grpc tls vmess-grpc)"
    echo "gRPC NTLS : $(vmess_link 80 grpc none vmess-grpc)"
    echo "TCP TLS   : $(vmess_link 11009 tcp tls /)"
    echo "TCP NTLS  : $(vmess_link 11010 tcp none /)"
    echo
    echo "TROJAN"
    echo "WS TLS    : trojan://${uuid}@${domain}:443?security=tls&type=ws&host=${domain}&path=${tws}&sni=${domain}#${user}"
    echo "WS NTLS   : trojan://${uuid}@${domain}:80?security=none&type=ws&host=${domain}&path=${tws}#${user}"
    echo "XHTTP TLS : trojan://${uuid}@${domain}:443?security=tls&type=xhttp&host=${domain}&path=${tx}&mode=auto&sni=${domain}#${user}"
    echo "XHTTP NTLS: trojan://${uuid}@${domain}:80?security=none&type=xhttp&host=${domain}&path=${tx}&mode=auto#${user}"
    echo "HU TLS    : trojan://${uuid}@${domain}:443?security=tls&type=httpupgrade&host=${domain}&path=${th}&sni=${domain}#${user}"
    echo "HU NTLS   : trojan://${uuid}@${domain}:80?security=none&type=httpupgrade&host=${domain}&path=${th}#${user}"
    echo "gRPC TLS  : trojan://${uuid}@${domain}:443?security=tls&type=grpc&serviceName=${tg}&sni=${domain}#${user}"
    echo "gRPC NTLS : trojan://${uuid}@${domain}:80?security=none&type=grpc&serviceName=${tg}#${user}"
    echo "TCP TLS   : trojan://${uuid}@${domain}:11029?security=tls&type=tcp&sni=${domain}#${user}"
    echo "TCP NTLS  : trojan://${uuid}@${domain}:11030?security=none&type=tcp#${user}"
}

list_accounts(){
    [ -s "$DB" ] || { echo "No Xray accounts"; return; }
    nl -w2 -s ') ' "$DB"
}

delete_account(){
    [ -s "$DB" ] || die "No Xray accounts"
    list_accounts
    read -rp "Select account number: " n
    line=$(sed -n "${n}p" "$DB")
    [ -n "$line" ] || die "Invalid account"
    user=$(awk '{print $1}' <<<"$line")
    uuid=$(awk '{print $3}' <<<"$line")
    python3 - "$CONFIG" "$user" "$uuid" <<'PY'
import json,sys,tempfile,os
p,user,uid=sys.argv[1:]
d=json.load(open(p))
for ib in d.get("inbounds",[]):
    if ib.get("protocol") not in ("vmess","vless","trojan"): continue
    c=ib.get("settings",{}).get("clients",[])
    ib["settings"]["clients"]=[x for x in c if x.get("email")!=user and x.get("id")!=uid and x.get("password")!=uid]
fd,tmp=tempfile.mkstemp(prefix=".xray.",dir=os.path.dirname(p))
with os.fdopen(fd,"w") as f: json.dump(d,f,indent=2); f.write("\n")
os.replace(tmp,p)
PY
    for db in "$DB" "$VMDB" "$VLDB" "$TRDB"; do
        [ -f "$db" ] && sed -i "/^${user//\//\\/} /d" "$db" || true
    done
    /usr/local/bin/xray run -test -config "$CONFIG" >/dev/null
    systemctl restart xray.service
    echo "Deleted $user ($uuid)"
}

renew_account(){
    [ -s "$DB" ] || die "No Xray accounts"
    list_accounts
    read -rp "Select account number: " n
    read -rp "Add days: " days
    [[ "$days" =~ ^[0-9]+$ ]] || die "Days must be a number"
    line=$(sed -n "${n}p" "$DB")
    [ -n "$line" ] || die "Invalid account"
    user=$(awk '{print $1}' <<<"$line")
    exp=$(awk '{print $2}' <<<"$line")
    uuid=$(awk '{print $3}' <<<"$line")
    newexp=$(date -d "$exp + $days days" +%Y-%m-%d)
    sed -i "${n}c\\${user} ${newexp} ${uuid}" "$DB"
    for db in "$VMDB" "$VLDB" "$TRDB"; do
      [ -f "$db" ] && sed -i "s/^${user//\//\\/} .*/${user} ${newexp} ${uuid}/" "$db" || true
    done
    echo "Renewed $user until $newexp"
}

case "${1:-}" in
  add) add_account ;;
  delete) delete_account ;;
  renew) renew_account ;;
  list) list_accounts ;;
  *) echo "Usage: xray-account {add|delete|renew|list}"; exit 2 ;;
esac
XRAYACCOUNT
chmod 700 /usr/local/bin/xray-account

# / / Installation Xray Service
cat > /etc/systemd/system/xray.service << END
[Unit]
Description=Xray Service By Akbar Maulana
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
END


# // Enable & Start Service
# Accept port Xray
for p in 80 443 11009 11010 11019 11020 11029 11030; do
  iptables -C INPUT -m state --state NEW -m tcp -p tcp --dport "$p" -j ACCEPT 2>/dev/null ||     iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport "$p" -j ACCEPT
done
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload
systemctl daemon-reload
if ! /usr/local/bin/xray run -test -config /etc/xray/config.json >/tmp/xray-config-test.log 2>&1; then
  echo "Xray configuration test failed:" >&2
  cat /tmp/xray-config-test.log >&2
  exit 1
fi
systemctl stop xray.service || true
systemctl enable xray.service
systemctl restart xray.service
systemctl --no-pager --full status xray.service || true

# Install Trojan Go
latest_version="$(curl -s "https://api.github.com/repos/p4gefau1t/trojan-go/releases" | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"
trojango_link="https://github.com/p4gefau1t/trojan-go/releases/download/v${latest_version}/trojan-go-linux-amd64.zip"
mkdir -p "/usr/bin/trojan-go"
mkdir -p "/etc/trojan-go"
cd `mktemp -d`
curl -sL "${trojango_link}" -o trojan-go.zip
unzip -q trojan-go.zip && rm -rf trojan-go.zip
mv trojan-go /usr/local/bin/trojan-go
chmod +x /usr/local/bin/trojan-go
mkdir /var/log/trojan-go/
touch /etc/trojan-go/akun.conf
touch /var/log/trojan-go/trojan-go.log

# Buat Config Trojan Go
cat > /etc/trojan-go/config.json << END
{
  "run_type": "server",
  "local_addr": "127.0.0.1",
  "local_port": 10087,
  "remote_addr": "127.0.0.1",
  "remote_port": 89,
  "log_level": 1,
  "log_file": "/var/log/trojan-go/trojan-go.log",
  "password": [
      "$trojango_uuid"
  ],
  "disable_http_check": true,
  "udp_timeout": 60,
  "ssl": {
    "verify": false,
    "verify_hostname": false,
    "enabled": false,
    "cert": "/etc/xray/xray.crt",
    "key": "/etc/xray/xray.key",
    "key_password": "",
    "cipher": "",
    "curves": "",
    "prefer_server_cipher": false,
    "sni": "$domain",
    "alpn": [
      "http/1.1"
    ],
    "session_ticket": true,
    "reuse_session": true,
    "plain_http_response": "",
    "fallback_addr": "127.0.0.1",
    "fallback_port": 0,
    "fingerprint": "firefox"
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "prefer_ipv4": true
  },
  "mux": {
    "enabled": false,
    "concurrency": 8,
    "idle_timeout": 60
  },
  "websocket": {
    "enabled": true,
    "path": "/trojango",
    "host": "$domain"
  },
    "api": {
    "enabled": false,
    "api_addr": "",
    "api_port": 0,
    "ssl": {
      "enabled": false,
      "key": "",
      "cert": "",
      "verify_client": false,
      "client_cert": []
    }
  }
}
END

# Installing Trojan Go Service
cat > /etc/systemd/system/trojan-go.service << END
[Unit]
Description=Trojan-Go Service By Akbar Maulana
Documentation=https://t.me/Akbar218
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
END

# Trojan Go Uuid
cat > /etc/trojan-go/uuid.txt << END
$trojango_uuid
END

# restart
# Trojan-Go is reached through the 80/443 nginx multiplex frontend; keep its backend private.
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload
systemctl daemon-reload
systemctl stop trojan-go
systemctl start trojan-go
systemctl enable trojan-go
systemctl restart trojan-go

cd
cp /root/domain /etc/xray
