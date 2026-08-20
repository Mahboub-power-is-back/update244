#!/bin/bash
set -euo pipefail
echo "SSH WebSocket public ports: 443 and 80"
echo "Nginx handles both ports and routes /sshws/ to 127.0.0.1:10005."
echo "Do not edit sslh or ws-tls for public ports."
nginx -t
systemctl reload nginx
echo "SSH WebSocket configuration is OK."
