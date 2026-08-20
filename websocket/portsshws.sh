#!/bin/bash
STATE=/etc/xray/paths.conf
path=$(grep -E '^SSH_WS_PATH=' "$STATE" 2>/dev/null|cut -d= -f2- || echo /sshws/)
printf 'MAHBOUB TUNNEL PREMIUM\nSSH WS TLS : 443 %s\nSSH WS HTTP: 80 %s\nHandshake : HTTP/1.1 101 Switching Protocols\n' "$path" "$path"
