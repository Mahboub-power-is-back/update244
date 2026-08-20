#!/bin/bash
set -euo pipefail
echo "SSH WebSocket compatibility endpoint: /sshnontls/"
echo "Public ports: 443 and 80"
echo "Nginx routes it to 127.0.0.1:10007."
echo "This script no longer changes sslh ports."
nginx -t
systemctl reload nginx
echo "SSH WebSocket compatibility configuration is OK."
